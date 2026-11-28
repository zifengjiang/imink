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
    /// 返回值必须是 **真正落库的行数**（由 `store` 统计），不能是「抓到的 detail 数」：
    /// 之前这里在 `store` 抛错时只打日志并返回 `details.count`，于是 UI 与后台通知
    /// 都会显示「加载了 N 条」，而事务其实整体回滚、库里 0 行。
    /// 落库失败现在直接向上抛出，由 `runPipeline` 呈现给用户。
    private func fetchAndPersistDetails(
        ids: [String],
        rootKey: String,
        query: @escaping (String) -> any SN3PersistedQuery,
        store: @escaping ([JSON]) async throws -> Int
    ) async throws -> Int {
        guard !ids.isEmpty else { return 0 }

        var details: [JSON] = []
        var fetchErrors: [String] = []
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

        guard !details.isEmpty else {
            fetchErrors.append("全部 \(ids.count) 条 detail 拉取失败")
            throw SN3Client.Error.noDetailFetched(message: fetchErrors.joined(separator: "; "))
        }

        // 恢复出来的库 / 新赛季素材里缺少 imageMap 记录时，getImageId(...) 会返回 0，
        // 而 weapon.imageMapId、coop.stageId 等外键会让整批插入回滚。
        // 插入前保证存在 id=0 的占位行，避免「因为一张未知图片而丢掉整批记录」。
        do {
            try SplatDatabase.shared.ensureUnknownImageMapRow()
        } catch {
            logError(error)
        }

        let saved = try await store(details)
        if details.count < ids.count {
            logError(
                NSError(domain: "imink.Sync", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "detail 拉取不完整：\(details.count)/\(ids.count)，已写入 \(saved) 条"
                ])
            )
        }
        return saved
    }

    /// 计数辅助：插入前后对比，得到真正落库的行数。
    private func countRows(in table: String) async throws -> Int {
        try await SplatDatabase.shared.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0
        }
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
                let before = try await self.countRows(in: "coop")
                let saved = try await self.fetchAndPersistDetails(
                    ids: validIds,
                    rootKey: "coopHistoryDetail",
                    query: { .coopHistoryDetail(id: $0) }
                ) { details in
                    try await SplatDatabase.shared.insertCoops(jsons: details)
                    await CoopListViewModel.shared.loadCoops(loadRecent: true)
                    let after = try await SplatDatabase.shared.dbQueue.read { db in
                        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM coop") ?? 0
                    }
                    return after - before
                }
                return saved
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
                let before = try await self.countRows(in: "battle")
                let saved = try await self.fetchAndPersistDetails(
                    ids: validIds,
                    rootKey: "vsHistoryDetail",
                    query: { .vsHistoryDetail(id: $0) }
                ) { details in
                    try await SplatDatabase.shared.insertBattles(jsons: details)
                    await BattleListViewModel.shared.loadBattles()
                    let after = try await SplatDatabase.shared.dbQueue.read { db in
                        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM battle") ?? 0
                    }
                    return after - before
                }
                return saved
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
                    Indicators.shared.updateIcon(for: IndicatorID, icon: .systemImage("exclamationmark.triangle"))
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
