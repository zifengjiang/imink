import Foundation
import SplatDatabase
import SwiftyJSON
import os.log
import SwiftUI

    // MARK: - Logging helpers
@inline(__always)
private func logError(_ error: any Error, _ message: StaticString = "❌ Error") {
    os_log(message, type: .error, String(describing: error))
}

    // MARK: - Task-local flags (fetch guards)
extension TaskLocal where Value == Bool {
    static let isFetchingCoops = TaskLocal<Bool>(wrappedValue: false)
    static let isFetchingBattles = TaskLocal<Bool>(wrappedValue: false)
}

    // MARK: - Utilities
private enum Gate {
    static func shouldProceed(last: Int, interval: Int, now: Int = Int(Date().timeIntervalSince1970)) -> Bool {
        return last + interval <= now
    }
}


    // MARK: - SN3Client token helper
extension SN3Client {
    func ensureToken() async throws {
            //        await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
        
        // 优先使用手动输入的token
        if AppUserDefaults.shared.useManualGameServiceToken, 
           let manualToken = AppUserDefaults.shared.manualGameServiceToken,
           !manualToken.isEmpty {
            try await setToken(manualToken)
        } else if let token = AppUserDefaults.shared.gameServiceToken {
            try await setToken(token)
        }
    }
}

    // MARK: - Generic fetch pipeline
extension SN3Client {
    @discardableResult
    func runPipeline(
        flag: TaskLocal<Bool>,
        refreshInterval: Int,
        lastRefreshTime: inout Int,
        icon: ImageResource,
        getValidIDs: @escaping () async throws -> [String],
        fetchAndStoreDetails: @escaping ([String]) async throws -> Int,
        groupId: String? = nil,  // 可选的任务组ID
        taskName: String? = nil  // 可选的子任务名称
    ) async -> Int?{
        guard !flag.get(), Gate.shouldProceed(last: lastRefreshTime, interval: refreshInterval) else { return nil}
        
        let IndicatorID: String
        let useTaskGroup: Bool
        
        // 如果提供了 groupId，使用任务组管理
        if let groupId = groupId {
            useTaskGroup = true
            IndicatorID = await Indicators.shared.acquireSharedIndicator(
                groupId: groupId,
                title: "正在加载...",
                icon: .progressIndicator
            )
            
            // 如果提供了 taskName，注册为子任务
            if let taskName = taskName {
                await Indicators.shared.registerSubTask(groupId: groupId, taskName: taskName)
            }
        } else {
            // 向后兼容：使用原有的独立 Indicator 逻辑
            useTaskGroup = false
            IndicatorID = UUID().uuidString
            await Indicators.shared.display(.init(id: IndicatorID, icon: .progressIndicator, title: "正在加载...", dismissType: .manual, isUserDismissible: false))
        }
        
        defer {
            if !useTaskGroup {
                Task {
                    await Indicators.shared.dismiss(with: IndicatorID, after: 2)
                }
            }
        }
        
        var count = 0
        do{
            try await flag.withValue(true) {
                do {
                    try Task.checkCancellation()
                    try await ensureToken()
                    let ids = try await getValidIDs()
                    try Task.checkCancellation()
                    guard !ids.isEmpty else {
                        if useTaskGroup, let groupId = groupId, let taskName = taskName {
                            await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                        } else {
                            await Indicators.shared.updateTitle(for: IndicatorID, title: "没有新纪录")
                            await Indicators.shared.updateIcon(for: IndicatorID, icon: .success)
                        }
                        lastRefreshTime = Int(Date().timeIntervalSince1970)
                        return
                    }
                    
                    // 如果使用任务组，不更新标题（由任务组统一管理）
                    if !useTaskGroup {
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "加载\(ids.count)项新纪录")
                    }
                    
                    let saved = try await fetchAndStoreDetails(ids)
                    count = saved
                    lastRefreshTime = Int(Date().timeIntervalSince1970)
                    
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        // 完成子任务，任务组会自动更新标题
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                    } else {
                        // 非任务组模式，更新标题和图标并 dismiss
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "加载了\(saved)个新纪录")
                        await Indicators.shared.updateIcon(for: IndicatorID, icon: .success)
                        await Indicators.shared.dismiss(with: IndicatorID, after: 1)
                    }
                    return
                } catch is CancellationError{
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                    } else {
                        await Indicators.shared.dismiss(with: IndicatorID)
                    }
                    return
                } catch SN3Client.Error.invalidGameServiceToken {
                    if AppUserDefaults.shared.useManualGameServiceToken {
                        if useTaskGroup, let groupId = groupId, let taskName = taskName {
                            await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                            await Indicators.shared.updateTitle(for: IndicatorID, title: "手动令牌已过期，请更新令牌")
                            await Indicators.shared.updateIcon(for: IndicatorID, icon: .image(Image(systemName: "exclamationmark.triangle")))
                        } else {
                            await Indicators.shared.updateTitle(for: IndicatorID, title: "手动令牌已过期，请更新令牌")
                            await Indicators.shared.updateIcon(for: IndicatorID, icon: .image(Image(systemName: "exclamationmark.triangle")))
                            await Indicators.shared.dismiss(with: IndicatorID, after: 3)
                        }
                        return
                    } else {
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "令牌已过期，重新获取...")
                        try await NSOAccountManager.shared.refreshGameServiceTokenManual(indicatorId: IndicatorID)
                    }
                }catch SN3Client.Error.tooManyRequests{
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "FAPI请求过于频繁，稍后重试...")
                    } else {
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "FAPI请求过于频繁，稍后重试...")
                        await Indicators.shared.dismiss(with: IndicatorID, after: 3)
                    }
                    return
                }catch {
                    logError(error)
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                    } else {
                        await Indicators.shared.dismiss(with: IndicatorID)
                    }
                    return
                }
            }
        }catch{
            logError(error)
        }
        return count
    }
}

    // MARK: - High-level APIs
extension SN3Client {
    @discardableResult
    func fetchCoops(groupId: String? = nil) async -> Int?{
        return await runPipeline(
            flag: .isFetchingCoops,
            refreshInterval: 300,
            lastRefreshTime: &AppUserDefaults.shared.coopsRefreshTime,
            icon: .salmonRun,
            getValidIDs: { [weak self] in
                guard let self else { return [] }
                let coopHistory = try await JSON(data: self.graphQL(.coopHistory))
                let ids = coopHistory["data"]["coopResult"]["historyGroups"]["nodes"].arrayValue
                    .flatMap { $0["historyDetails"]["nodes"].arrayValue.map { $0["id"].stringValue } }
                let summary = CoopSummary(json: coopHistory["data"]["coopResult"])
                CoopSummary.save(summary)
                return try SplatDatabase.shared.filterNotExists(in: .coop, ids: ids)
            },
            fetchAndStoreDetails: { [weak self] validIds in
                guard let self else { return 0 }
                var results: [JSON] = []
                await withTaskGroup(of: JSON?.self) { group in
                    for id in validIds {
                        group.addTask { [weak self] in
                            guard let self else { return nil }
                            do { return try await JSON(data: self.graphQL(.coopHistoryDetail(id: id))) }
                            catch { logError(error); return nil }
                        }
                    }
                    for await result in group {
                        if let detail = result { results.append(detail["data"]["coopHistoryDetail"]) }
                    }
                }
                if !results.isEmpty {
                    do {
                        try await SplatDatabase.shared.insertCoops(jsons: results)
                        await CoopListViewModel.shared.loadCoops(loadRecent: true)
                    } catch { logError(error) }
                }
                return results.count
            },
            groupId: groupId,
            taskName: groupId != nil ? "获取鲑鱼跑记录" : nil
        )
    }
    @discardableResult
    func fetchBattles(groupId: String? = nil) async -> Int?{
        return await runPipeline(
            flag: .isFetchingBattles,
            refreshInterval: 300,
            lastRefreshTime: &AppUserDefaults.shared.battlesRefreshTime,
            icon: .regularBattle,
            getValidIDs: { [weak self] in
                guard let self else { return [] }
                let queries: [any SN3PersistedQuery] = [
                    .latestBattleHistories, .regularBattleHistories, .bankaraBattleHistories,
                    .privateBattleHistories, .eventBattleHistories, .xBattleHistories
                ]
                var allIDs: [String] = []
                try await withThrowingTaskGroup(of: JSON?.self) { group in
                    for q in queries {
                        group.addTask { [weak self] in
                            guard let self else { return nil }
                            return try JSON(data: await self.graphQL(q))
                        }
                    }
                    for try await result in group {
                        guard let json = result, let rootKey = json["data"].dictionary?.keys.first else { continue }
                        let ids = json["data"][rootKey]["historyGroups"]["nodes"].arrayValue
                            .flatMap { $0["historyDetails"]["nodes"].arrayValue.compactMap { $0["id"].string } }
                        allIDs.append(contentsOf: ids)
                    }
                }
                return try SplatDatabase.shared.filterNotExists(in: .battle, ids: Array(Set(allIDs)))
            },
            fetchAndStoreDetails: { [weak self] validIds in
                guard let self else { return 0 }
                var results: [JSON] = []
                await withTaskGroup(of: JSON?.self) { group in
                    for id in validIds {
                        group.addTask { [weak self] in
                            guard let self else { return nil }
                            do { return try await JSON(data: self.graphQL(.vsHistoryDetail(id: id))) }
                            catch { logError(error); return nil }
                        }
                    }
                    for await result in group {
                        if let detail = result { results.append(detail["data"]["vsHistoryDetail"]) }
                    }
                }
                if !results.isEmpty {
                    do {
                        try await SplatDatabase.shared.insertBattles(jsons: results)
                        await BattleListViewModel.shared.loadBattles()
                    } catch { logError(error) }
                }
                return results.count
            },
            groupId: groupId,
            taskName: groupId != nil ? "获取对战记录" : nil
        )
    }


    func fetchRecord<T: SwiftyJSONDecodable>(_ queryType: any SN3PersistedQuery,  maxRetries: Int = 3) async -> T? {
        var retryCount = 0
        let IndicatorID = UUID().uuidString
        defer {
            Indicators.shared.dismiss(with: IndicatorID, after: 2)
        }
        Indicators.shared.display(.init(id: IndicatorID, icon: .progressIndicator, title: "正在加载...", dismissType: .manual, isUserDismissible: false))
        while retryCount < maxRetries {
            do {
                try await ensureToken()
                let data = try await JSON(data: self.graphQL(queryType))
                if retryCount > 0 {
                    Indicators.shared.updateTitle(for: IndicatorID, title: "加载成功")
                }
                return T(json: data)
            } catch SN3Client.Error.invalidGameServiceToken {
                if AppUserDefaults.shared.useManualGameServiceToken {
                    Indicators.shared.updateTitle(for: IndicatorID, title: "手动令牌已过期，请在设置中更新")
                    Indicators.shared.updateIcon(for: IndicatorID, icon: .image(Image(systemName: "exclamationmark.triangle")))
                    return nil
                } else {
                    do{
                        try await NSOAccountManager.shared.refreshGameServiceTokenManual()
                    }catch{
                        logError(error)
                    }
                    retryCount += 1
                }
            } catch is CancellationError {
                Indicators.shared.dismiss(with: IndicatorID)
                return nil
            } catch {
                logError(error)
                retryCount += 1
                if retryCount < maxRetries {
                    Indicators.shared.updateTitle(for: IndicatorID, title: "第\(retryCount)次重试中...")
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        Indicators.shared.updateTitle(for: IndicatorID, title: "加载失败")
        return nil
    }
}

extension Array: SwiftyJSONDecodable where Element == StageRecord {
    init(json: JSON) {
        self = json["data"]["stageRecords"]["nodes"].arrayValue.map { StageRecord(json: $0) }
    }
}

// MARK: - Friend List Support

extension SN3Client {
    /// 获取好友列表
    func fetchFriendList() async -> FriendListResult? {
        do {
            try await ensureToken()
            let data = try await JSON(data: self.graphQL(.friendList))
            return FriendListResult(json: data)
        } catch {
            logError(error, "获取好友列表失败")
            return nil
        }
    }
}

// MARK: - FriendListResult SwiftyJSONDecodable Support

extension FriendListResult: SwiftyJSONDecodable {
    init(json: JSON) {
        self.data = FriendListResult.Data(json: json["data"])
    }
}

extension FriendListResult.Data: SwiftyJSONDecodable {
    init(json: JSON) {
        self.currentFest = json["currentFest"].exists() ? FriendListResult.Data.CurrentFest(json: json["currentFest"]) : nil
        self.friends = json["friends"].exists() ? FriendListResult.Data.Friends(json: json["friends"]) : nil
    }
}

extension FriendListResult.Data.CurrentFest: SwiftyJSONDecodable {
    init(json: JSON) {
        self.id = json["id"].stringValue
        self.state = json["state"].stringValue
        self.teams = json["teams"].arrayValue.map { FriendListResult.Data.CurrentFest.FestTeam(json: $0) }
    }
}

extension FriendListResult.Data.CurrentFest.FestTeam: SwiftyJSONDecodable {
    init(json: JSON) {
        self.id = json["id"].stringValue
        self.color = FriendListResult.Data.CurrentFest.FestTeam.Color(json: json["color"])
    }
}

extension FriendListResult.Data.CurrentFest.FestTeam.Color: SwiftyJSONDecodable {
    init(json: JSON) {
        self.r = json["r"].floatValue
        self.g = json["g"].floatValue
        self.b = json["b"].floatValue
        self.a = json["a"].floatValue
    }
}

extension FriendListResult.Data.Friends: SwiftyJSONDecodable {
    init(json: JSON) {
        self.nodes = json["nodes"].arrayValue.map { FriendListResult.Data.Friends.Node(json: $0) }
    }
}

extension FriendListResult.Data.Friends.Node: SwiftyJSONDecodable {
    init(json: JSON) {
        self.id = json["id"].stringValue
        self.coopRule = json["coopRule"].string
        self.isLocked = json["isLocked"].bool
        self.isVcEnabled = json["isVcEnabled"].bool
        self.nickname = json["nickname"].stringValue
        self.onlineState = json["onlineState"].stringValue
        self.playerName = json["playerName"].string
        self.userIcon = json["userIcon"].exists() ? FriendListResult.Data.Friends.Node.UserIcon(json: json["userIcon"]) : nil
        self.vsMode = json["vsMode"].exists() ? VsMode(json: json["vsMode"]) : nil
        self.isFavorite = json["isFavorite"].bool
    }
}

extension FriendListResult.Data.Friends.Node.UserIcon: SwiftyJSONDecodable {
    init(json: JSON) {
        self.height = json["height"].intValue
        self.url = json["url"].stringValue
        self.width = json["width"].intValue
    }
}

extension VsMode: SwiftyJSONDecodable {
    init(json: JSON) {
        self.id = json["id"].stringValue
        self.mode = json["mode"].stringValue
    }
}
