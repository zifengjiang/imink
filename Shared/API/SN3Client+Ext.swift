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
        await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
        if let token = AppUserDefaults.shared.gameServiceToken {
            try await setToken(token)
        }
    }
}

    // MARK: - Generic fetch pipeline
extension SN3Client {
    func runPipeline(
        flag: TaskLocal<Bool>,
        refreshInterval: Int,
        lastRefreshTime: inout Int,
        icon: ImageResource,
        getValidIDs: @escaping () async throws -> [String],
        fetchAndStoreDetails: @escaping ([String]) async throws -> Int
    ) async {
        guard !flag.get(), Gate.shouldProceed(last: lastRefreshTime, interval: refreshInterval) else { return }
        let IndicatorID = UUID().uuidString
        defer {

        }
        Indicators.shared.display(.init(id: IndicatorID, icon: .progressIndicator, title: "正在加载...", dismissType: .manual, isUserDismissible: false))

        await flag.withValue(true) {
            let maxRetries = 2
            var attempt = 0
            defer {
                Indicators.shared.dismiss(with: IndicatorID)
            }
            while attempt < maxRetries {
                do {
                    try Task.checkCancellation()
                    try await ensureToken()
                    let ids = try await getValidIDs()
                    try Task.checkCancellation()
                    guard !ids.isEmpty else {
                        Indicators.shared.updateTitle(for: IndicatorID, title: "没有新纪录")
                        Indicators.shared.updateIcon(for: IndicatorID, icon: .success)
                        lastRefreshTime = Int(Date().timeIntervalSince1970)
                        return
                    }
                    Indicators.shared.updateTitle(for: IndicatorID, title: "加载\(ids.count)项新纪录")
                    let saved = try await fetchAndStoreDetails(ids)
                    lastRefreshTime = Int(Date().timeIntervalSince1970)
                    Indicators.shared.updateTitle(for: IndicatorID, title: "加载了\(saved)个新纪录")
                    Indicators.shared.updateIcon(for: IndicatorID, icon: .success)
                    return
                } catch is CancellationError{
                    Indicators.shared.dismiss(with: IndicatorID)
                    return
                } catch SN3Client.Error.invalidGameServiceToken {
                    if attempt < maxRetries { Indicators.shared.updateTitle(for: IndicatorID, title: "令牌已过期，重新获取...") }
                    else { Indicators.shared.updateTitle(for: IndicatorID, title: "令牌已过期，重试获取失败")}
                    await NSOAccountManager.shared.refreshGameServiceTokenManual()
                    attempt += 1
                }catch {
                    logError(error)
                    attempt += 1
                    Indicators.shared.updateTitle(for: IndicatorID, title: "第\(attempt)次重试中...")
                    if attempt < maxRetries {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            }
            Indicators.shared.updateTitle(for: IndicatorID, title: "加载失败")
            Indicators.shared.updateIcon(for: IndicatorID, icon: .image(Image(systemName: "xmark.icloud")))

        }
    }
}

    // MARK: - High-level APIs
extension SN3Client {
    func fetchCoops() async {
        await runPipeline(
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
            }
        )
    }

    func fetchBattles() async {
        await runPipeline(
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
            }
        )
    }


    func fetchRecord<T: SwiftyJSONDecodable>(_ queryType: any SN3PersistedQuery,  maxRetries: Int = 3) async -> T? {
        var retryCount = 0
        let IndicatorID = UUID().uuidString
        defer {
            Indicators.shared.dismiss(with: IndicatorID)
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
                await NSOAccountManager.shared.refreshGameServiceTokenManual()
                retryCount += 1
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
