import Foundation
import SwiftUI
import SplatDatabase
import Combine
import GRDB
import os
import SwiftyJSON

class HomeViewModel: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = HomeViewModel()
    
    @Published var totalCoop: Int = 0
    @Published var totalBattle: Int = 0
    @Published var last500Battle: [Bool?] = []
    @Published var last500Coop: [Bool?] = []
    @Published var schedules: [Schedule] = []
    @Published var lastCoopGroupId: Int?
    @Published var lastBattleGroupId: Int?
    @Published var salmonRunStatus: CoopGroupStatus?
    @Published var battleStatus: BattleGroupStatus?
    @Published var lastCoopTime: Date?
    
    // MARK: - Stage Records Data
    @Published var stageRecords: [StageRecord] = []
    @Published var coopRecord: CoopRecord?
    @Published var isLoadingStageRecords = false
    @Published var isLoadingCoopRecord = false
    
    var scheduleGroups: [Date: [Schedule]] {
        Dictionary(grouping: schedules.filter { $0.mode != .salmonRun }, by: { $0.startTime })
    }
    
    var salmonRunSchedules: [Schedule] {
        schedules.filter { $0.mode == .salmonRun }.sorted { $0.rule1.rawValue > $1.rule1.rawValue }
    }
    
    private var cancelBag = Set<AnyCancellable>()
    private var scheduleCancelBag = Set<AnyCancellable>()
    private var loginStateCancelBag = Set<AnyCancellable>()  // 用于监听登录状态
    
    init() {
        // 根据当前的登录状态进行处理
        handleLoginStateChange(isLogin: AppState.shared.isLogin)
        
        // 监听登录状态变化
        AppState.shared.$isLogin
            .sink { [weak self] isLogin in
                self?.handleLoginStateChange(isLogin: isLogin)
            }
            .store(in: &loginStateCancelBag)
        loadSchedules()
        loadCachedRecords()
    }
    
    // 取消数据订阅，但不取消登录状态监听
    func cancelSubscriptions() {
        cancelBag.forEach { $0.cancel() }
        cancelBag.removeAll()
    }
    
    func handleLoginStateChange(isLogin: Bool) {
        if isLogin {
            // 用户已登录，加载数据
            updateStatus()
        } else {
            // 用户未登录，清空数据
            clearData()
            cancelSubscriptions()
        }
    }
    
    func clearData() {
        salmonRunStatus = nil
        lastCoopGroupId = nil
        lastBattleGroupId = nil
        last500Coop = []
        last500Battle = []
        battleStatus = nil
        lastCoopTime = nil
        stageRecords = []
        coopRecord = nil
    }
    
    func updateStatus() {
        cancelBag = Set<AnyCancellable>()
        
        SplatDatabase.shared.totalCoopCount()
            .catch { error -> Just<Int> in
                os_log("Database Error: [totalCount] \(error.localizedDescription)")
                return Just<Int>(0)
            }
            .assign(to: \.totalCoop, on: self)
            .store(in: &cancelBag)
        
        SplatDatabase.shared.totalBattleCount()
            .catch { error -> Just<Int> in
                os_log("Database Error: [totalCount] \(error.localizedDescription)")
                return Just<Int>(0)
            }
            .assign(to: \.totalBattle, on: self)
            .store(in: &cancelBag)
        
        ValueObservation
            .tracking { db in
                try Int.fetchOne(db, sql: "SELECT MAX(GroupId) FROM coop_group_status_view WHERE accountId = ?", arguments: [AppUserDefaults.shared.accountId])
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
            .catch { error -> Just<Int?> in
                logError(error)
                return Just<Int?>(nil)
            }
            .assign(to: \.lastCoopGroupId, on: self)
            .store(in: &cancelBag)
        
        ValueObservation
            .tracking { db in
                try Int.fetchOne(db, sql: "SELECT MAX(GroupId) FROM battle_group_status_view WHERE accountId = ?", arguments: [AppUserDefaults.shared.accountId])
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
            .catch { error -> Just<Int?> in
                logError(error)
                return Just<Int?>(nil)
            }
            .assign(to: \.lastBattleGroupId, on: self)
            .store(in: &cancelBag)
        
        
        
        $totalCoop
            .map{ _ in SplatDatabase.shared.fetchLast500(isCoop:true) }
            .assign(to: \.last500Coop, on: self)
            .store(in: &cancelBag)
        
        $totalBattle
            .map{ _ in SplatDatabase.shared.fetchLast500(isCoop:false) }
            .assign(to: \.last500Battle, on: self)
            .store(in: &cancelBag)
        
        $lastCoopGroupId
            .sink{ _ in
                if let lastCoopGroupId = self.lastCoopGroupId{
                    CoopGroupStatus.fetchOne(identifier: (lastCoopGroupId, AppUserDefaults.shared.accountId))
                        .catch { error -> Just<CoopGroupStatus?> in
                            logError(error)
                            return Just<CoopGroupStatus?>(nil)
                        }
                        .assign(to: \.salmonRunStatus, on: self)
                        .store(in: &self.cancelBag)
                }
            }
            .store(in: &cancelBag)
        
        $lastBattleGroupId
            .sink{ _ in
                if let lastBattleGroupId = self.lastBattleGroupId{
                    BattleGroupStatus.fetchOne(identifier: (lastBattleGroupId, AppUserDefaults.shared.accountId))
                        .catch { error -> Just<BattleGroupStatus?> in
                            logError(error)
                            return Just<BattleGroupStatus?>(nil)
                        }
                        .assign(to: \.battleStatus, on: self)
                        .store(in: &self.cancelBag)
                }
            }
            .store(in: &cancelBag)
        
        // 获取最新的 coop 时间
        ValueObservation
            .tracking { db in
                try Date.fetchOne(db, sql: "SELECT MAX(playedTime) FROM coop WHERE accountId = ?", arguments: [AppUserDefaults.shared.accountId])
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
            .catch { error -> Just<Date?> in
                logError(error)
                return Just<Date?>(nil)
            }
            .assign(to: \.lastCoopTime, on: self)
            .store(in: &cancelBag)
    }
    
    
    func loadSchedules(date:Date = Date()){
        scheduleCancelBag = Set<AnyCancellable>()
        DispatchQueue.main.async{
            Schedule.fetchAll(identifier: SQLRequest(sql: "SELECT * FROM schedule WHERE startTime >= ? OR (startTime <= ? AND endTime >= ?) ORDER BY startTime ASC", arguments: [date, date, date]))
                .catch { error -> Just<[Schedule]> in
                    os_log("Database Error: [loadSchedules] \(error.localizedDescription)")
                    return Just<[Schedule]>([])
                }
                .map{
                    $0.sorted(by: { $0.startTime < $1.startTime })
                }
                .assign(to: \.schedules, on: self)
                .store(in: &self.scheduleCancelBag)
        }
    }
    
    func fetchSchedules() async {
        // 5分钟内不重复获取
        guard AppUserDefaults.shared.scheduleRefreshTime + 300 <= Int(Date().timeIntervalSince1970 ) else{ return }
        
        // 使用全局任务组ID，所有任务共享同一个indicator
        let groupId = Indicators.globalTaskGroupId
        let indicatorId = await Indicators.shared.acquireSharedIndicator(
            groupId: groupId,
            title: "获取赛程中",
            icon: .progressIndicator
        )
        
        do{
            print("fetchSchedules")
            // 注册子任务
            await Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取赛程-获取赛程数据")
            
            let json = try await Splatoon3InkAPI.schedule.GetJSON()
            try await SplatDatabase.shared.dbQueue.write { db in
                try insertSchedules(json: json, db: db)
            }
            loadSchedules()
            
            // 完成子任务
            await Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取赛程-获取赛程数据")
            
            // 完成任务组（只有在没有其他活跃任务时才真正完成）
            await Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: "获取赛程成功")
            AppUserDefaults.shared.scheduleRefreshTime = Int(Date().timeIntervalSince1970)
        }catch{
            loadSchedules()
            logError(error)
            // 完成子任务
            await Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取赛程-获取赛程数据")
            // 完成任务组（只有在没有其他活跃任务时才真正完成）
            await Indicators.shared.completeTaskGroup(groupId: groupId, success: false, message: "获取赛程失败")
        }
    }
    
    // MARK: - Stage Records Management
    
    /// 从缓存加载场地记录数据
    func loadCachedRecords() {
        // 加载场地记录缓存
        let cachedStageRecords = AppUserDefaults.shared.stageRecordsCache
        if !cachedStageRecords.isEmpty {
            self.stageRecords = cachedStageRecords
        }
        
        // 加载Coop记录缓存
        if let cachedCoopRecord = AppUserDefaults.shared.coopRecordCache {
            self.coopRecord = cachedCoopRecord
        }
    }
    
    /// 获取场地记录数据
    func fetchStageRecords() async {
        guard !isLoadingStageRecords else { return }
        
        await MainActor.run {
            isLoadingStageRecords = true
        }
        
        let records: [StageRecord] = await SN3Client.shared.fetchRecord(.stageRecord) ?? []
        
        await MainActor.run {
            self.stageRecords = records
            self.isLoadingStageRecords = false
            // 保存到缓存
            AppUserDefaults.shared.stageRecordsCache = records
        }
    }
    
    /// 获取Coop记录数据
    func fetchCoopRecord() async {
        guard !isLoadingCoopRecord else { return }
        
        await MainActor.run {
            isLoadingCoopRecord = true
        }
        
        let record: CoopRecord? = await SN3Client.shared.fetchRecord(.coopRecord)
        
        await MainActor.run {
            self.coopRecord = record
            self.isLoadingCoopRecord = false
            // 保存到缓存
            if let record = record {
                AppUserDefaults.shared.coopRecordCache = record
            }
        }
    }
    
    /// 根据场地ID获取场地记录
    func getStageRecord(for stageId: String) -> StageRecord? {
        return stageRecords.first { $0.nameId == stageId }
    }
    
    /// 根据场地ID获取Coop场地记录
    func getCoopStageRecord(for stageId: String) -> StageHighestRecord? {
        return coopRecord?.stageHighestRecords.first { $0.coopStage == stageId }
    }
    
    /// 确保场地记录数据可用，如果缓存为空则自动获取
    func ensureStageRecordsAvailable() async {
        if stageRecords.isEmpty && !isLoadingStageRecords {
            await fetchStageRecords()
        }
    }
    
    /// 确保Coop记录数据可用，如果缓存为空则自动获取
    func ensureCoopRecordAvailable() async {
        if coopRecord == nil && !isLoadingCoopRecord {
            await fetchCoopRecord()
        }
    }
    
}

extension Schedule: @retroactive Identifiable {
    public var id:String{
        UUID().uuidString
    }
}

extension SplatDatabase {
    func fetchLast500(isCoop:Bool) -> [Bool?] {
        return try! dbQueue.read { db in
            var rows: [Row]
            if isCoop{
                rows = try! SplatDatabaseSQL.last_500_coop(accountId: AppUserDefaults.shared.accountId).request.fetchAll(db)
            }else{
                rows = try! SplatDatabaseSQL.last_500_battle(accountId: AppUserDefaults.shared.accountId).request.fetchAll(db)
            }
            return rows.map { row in
                if let result = row["result"] as Bool? {
                    return result
                }
                return nil
            }
        }
    }
    
    func totalCoopCount() -> AnyPublisher<Int, Error> {
        return ValueObservation
            .tracking { db in
                try Coop.filter(sql: "isDeleted = 0").fetchCount(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
    
    func totalBattleCount() -> AnyPublisher<Int, Error> {
        return ValueObservation
            .tracking { db in
                try Battle.filter(sql: "isDeleted = 0").fetchCount(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}
