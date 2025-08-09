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

    // MARK: - DB batch inserts
extension SplatDatabase {
    public func insertBattles(jsons: [JSON]) async throws {
        try await dbQueue.write { db in
            for json in jsons {
                do { try self.insertBattle(json: json, db: db) }
                catch { logError(error) }
            }
        }
    }

    public func insertCoops(jsons: [JSON]) async throws {
        try await dbQueue.write { db in
            for json in jsons {
                do { try self.insertCoop(json: json, db: db) }
                catch { logError(error) }
            }
        }
    }
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

private struct ProgressUI {
    static func noNewRecords(icon: ImageResource) {
        Indicators.shared.display(.init(icon: .image(Image(icon)), title: "无新纪录", dismissType: .after(2)))
    }
    static func startingBatch(count: Int) {
        Indicators.shared.display(.init(icon: .progressIndicator, title: "加载\(count)项纪录", dismissType: .after(5)))
    }
    static func finishedBatch(count: Int) {
        Indicators.shared.display(.init(icon: .success, title: "已加载\(count)项纪录", dismissType: .after(3)))
    }
    static func retrying(_ n: Int) {
        Indicators.shared.display(.init(icon: .systemImage("arrow.clockwise"), title: "重试中...", expandedText: "第\(n)次重试", dismissType: .after(2)))
    }
    static func failOnce(message: String) {
        Indicators.shared.display(.init(icon: .systemImage("xmark.seal"), title: "加载失败", expandedText: message, dismissType: .automatic, style: .error))
    }
    static func failMax() {
        Indicators.shared.display(.init(icon: .systemImage("xmark.seal"), title: "达到最大重试次数", expandedText: "请稍后再试", dismissType: .automatic, style: .error))
    }
    static func retrySucceeded() {
        Indicators.shared.display(.init(icon: .success, title: "重试成功", dismissType: .after(3)))
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

        await flag.withValue(true) {
            let maxRetries = 2
            var attempt = 0
            while attempt < maxRetries {
                do {
                    try await ensureToken()
                    let ids = try await getValidIDs()
                    guard !ids.isEmpty else {
                        ProgressUI.noNewRecords(icon: icon)
                        lastRefreshTime = Int(Date().timeIntervalSince1970)
                        return
                    }
                    ProgressUI.startingBatch(count: ids.count)
                    let saved = try await fetchAndStoreDetails(ids)
                    lastRefreshTime = Int(Date().timeIntervalSince1970)
                    ProgressUI.finishedBatch(count: saved)
                    return
                } catch SN3Client.Error.invalidGameServiceToken {
                    await NSOAccountManager.shared.refreshGameServiceTokenManual()
                    attempt += 1
                    if attempt < maxRetries { ProgressUI.retrying(attempt) }
                } catch {
                    logError(error)
                    attempt += 1
                    ProgressUI.failOnce(message: "第\(attempt)次尝试失败: \(error.localizedDescription)")
                    if attempt < maxRetries {
                        ProgressUI.retrying(attempt)
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            }
            ProgressUI.failMax()
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
            refreshInterval: 10,
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
        while retryCount < maxRetries {
            do {
                try await ensureToken()
                let data = try await JSON(data: self.graphQL(queryType))
                if retryCount > 0 { ProgressUI.retrySucceeded() }
                return T(json: data)
            } catch SN3Client.Error.invalidGameServiceToken {
                await NSOAccountManager.shared.refreshGameServiceTokenManual()
                retryCount += 1
            } catch {
                logError(error)
                retryCount += 1
                if retryCount < maxRetries {
                    ProgressUI.retrying(retryCount)
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        ProgressUI.failMax()
        return nil
    }
}

extension Array: SwiftyJSONDecodable where Element == StageRecord {
    init(json: JSON) {
        self = json["data"]["stageRecords"]["nodes"].arrayValue.map { StageRecord(json: $0) }
    }
}
