import Foundation
import GRDB
import SwiftyJSON
import SplatDatabase
import SwiftUI
import os.log

    // MARK: - High-level APIs
extension SN3Client {
    /// 并发拉取一批 detail，成功后交给 `store` 落库。
    ///
    /// 对战与打工的拉取流程只有查询类型、响应根键和落库方式不同，
    /// 这里把并发抓取、错误忽略与计数逻辑统一起来。
    private func fetchAndPersistDetails(
        ids: [String],
        rootKey: String,
        query: @escaping (String) -> any SN3PersistedQuery,
        store: @escaping ([JSON]) async throws -> Void
    ) async -> Int {
        guard !ids.isEmpty else { return 0 }

        var details: [JSON] = []
        await withTaskGroup(of: JSON?.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    do {
                        let json = try await JSON(data: self.graphQL(query(id)))
                        return json["data"][rootKey]
                    } catch {
                        logError(error)
                        return nil
                    }
                }
            }
            for await detail in group {
                if let detail { details.append(detail) }
            }
        }

        guard !details.isEmpty else { return 0 }
        do {
            try await store(details)
        } catch {
            logError(error)
        }
        return details.count
    }

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
                return await self.fetchAndPersistDetails(
                    ids: validIds,
                    rootKey: "coopHistoryDetail",
                    query: { .coopHistoryDetail(id: $0) }
                ) { details in
                    try await SplatDatabase.shared.insertCoops(jsons: details)
                    await CoopListViewModel.shared.loadCoops(loadRecent: true)
                }
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
                return await self.fetchAndPersistDetails(
                    ids: validIds,
                    rootKey: "vsHistoryDetail",
                    query: { .vsHistoryDetail(id: $0) }
                ) { details in
                    try await SplatDatabase.shared.insertBattles(jsons: details)
                    await BattleListViewModel.shared.loadBattles()
                }
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
        Toast.progress(id: IndicatorID, title: "正在加载...")
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
            logError(error)
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
