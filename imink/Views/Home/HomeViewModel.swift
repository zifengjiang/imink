import Foundation
import SwiftUI
import SplatDatabase
import Combine
import GRDB
import os
import SwiftyJSON

class HomeViewModel: ObservableObject {

    @Published var totalCoop: Int = 0
    @Published var totalBattle: Int = 0
    @Published var last500Battle: [Bool?] = []
    @Published var last500Coop: [Bool?] = []
    @Published var schedules: [Schedule] = []
    @Published var lastCoopGroupId: Int?
    @Published var lastBattleGroupId: Int?
    @Published var salmonRunStatus: CoopGroupStatus?
    @Published var battleStatus: BattleGroupStatus?

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
        let IndicatorId = UUID().uuidString
        do{
            print("fetchSchedules")
            Indicators.shared.display(Indicator(id: IndicatorId, icon: .progressIndicator, title: "获取赛程中", dismissType: .manual, isUserDismissible: false))
            let json = try await Splatoon3InkAPI.schedule.GetJSON()
            try await SplatDatabase.shared.dbQueue.write { db in
                try insertSchedules(json: json, db: db)
            }
            loadSchedules()
            Indicators.shared.updateTitle(for: IndicatorId, title: "获取赛程成功")
            Indicators.shared.updateIcon(for: IndicatorId, icon: .success)
            AppUserDefaults.shared.scheduleRefreshTime = Int(Date().timeIntervalSince1970)
        }catch{
            loadSchedules()
            logError(error)
            Indicators.shared.updateTitle(for: IndicatorId, title: "获取赛程失败")
            Indicators.shared.updateIcon(for: IndicatorId, icon: .image(Image(systemName: "xmark.icloud")))
        }
        Indicators.shared.dismiss(with: IndicatorId)
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
            .tracking(
                Coop
                //                    .filter(sql: "accountId = ?", arguments: [0])
                    .fetchCount
            )
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func totalBattleCount() -> AnyPublisher<Int, Error> {
        return ValueObservation
            .tracking(
                Battle
                //                    .filter(sql: "accountId = ?", arguments: [0])
                    .fetchCount
            )
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}
