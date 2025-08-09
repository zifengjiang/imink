import Foundation
import SplatDatabase
import SwiftyJSON
import os.log
import SwiftUI

extension SplatDatabase {
    public func insertBattles(jsons:[JSON]) async throws {
        try await self.dbQueue.write { db in
            for json in jsons{
                do{
                    try self.insertBattle(json: json, db: db)
                }catch{
                    logError(error)
                }
            }
        }
    }
}

extension TaskLocal where Value == Bool{
    static let isFetchingCoops: TaskLocal<Bool> = TaskLocal<Bool>(wrappedValue: false)
    static let isFetchingBattles = TaskLocal<Bool>(wrappedValue: false)
}

extension SN3Client {
    static let isFetchingCoops = TaskLocal<Bool>(wrappedValue: false)
    
    func _fetchCoops() async {
        
    }
    
    func fetchCoops() async {
        await fetchRecords(isFetching: .isFetchingCoops, refreshInterval: 300, lastRefreshTime: &AppUserDefaults.shared.coopsRefreshTime,icon: .salmonRun) {
            let coopHistory = try await JSON(data: self.graphQL(.coopHistory))
            let ids = coopHistory["data"]["coopResult"]["historyGroups"]["nodes"].arrayValue.flatMap { nodeJSON in
                return nodeJSON["historyDetails"]["nodes"].arrayValue.map { detailJSON in
                    return detailJSON["id"].stringValue
                }
            }
            let summary:CoopSummary = CoopSummary(json: coopHistory["data"]["coopResult"])
            CoopSummary.save(summary)
            let validIds = try SplatDatabase.shared.filterNotExists(in:.coop, ids: ids)
            
            return validIds
        } fetchDetails: { validIds in
            return await withTaskGroup(of: JSON?.self) { group in
                var jsonResults: [JSON] = []
                for coop in validIds{
                    group.addTask {
                        do{
                            return try await JSON(data: self.graphQL(.coopHistoryDetail(id: coop)))
                        }catch{
                            logError(error)
                        }
                        return nil
                    }
                }
                for await result in group {
                    if let detailJSON = result {
                        jsonResults.append(detailJSON["data"]["coopHistoryDetail"])
                    }
                }
                do {
                    if !jsonResults.isEmpty {
                        try await SplatDatabase.shared.insertCoops(jsons: jsonResults)
                        await CoopListViewModel.shared.loadCoops(loadRecent:true)
                    }
                } catch {
                    logError(error)
                }
                return jsonResults.count
            }
            
        }
    }
    
    func fetchBattles() async {
        await fetchRecords(isFetching: .isFetchingBattles, refreshInterval: 10, lastRefreshTime: &AppUserDefaults.shared.battlesRefreshTime,icon: .regularBattle) {
            try await withThrowingTaskGroup(of: JSON?.self) { group in
                var ids: [String] = []
                let queries:[any SN3PersistedQuery] = [
                    .latestBattleHistories,
                    .regularBattleHistories,
                    .bankaraBattleHistories,
                    .privateBattleHistories,
                    .eventBattleHistories,
                    .xBattleHistories
                ]
                
                queries.forEach { query in
                    group.addTask {
                        return try JSON(data:await self.graphQL(query))
                    }
                }
                
                for try await result in group {
                    if let detailJSON = result, let key = detailJSON["data"].dictionary?.keys.first as String? {
                        ids.append(contentsOf: detailJSON["data"][key]["historyGroups"]["nodes"].arrayValue.flatMap{ ele in
                            ele["historyDetails"]["nodes"].arrayValue.compactMap{ele1 in
                                ele1["id"].stringValue
                            }
                        })
                    }
                }
                
                return try SplatDatabase.shared.filterNotExists(in:.battle, ids: ids.removingDuplicates())
            }
            
        } fetchDetails: { validIds in
            return await withTaskGroup(of: JSON?.self) { group in
                var jsonResults: [JSON] = []
                for battle in validIds{
                    group.addTask {
                        do{
                            return try await JSON(data: self.graphQL(.vsHistoryDetail(id: battle)))
                        }catch{
                            logError(error)
                        }
                        return nil
                    }
                }
                for await result in group {
                    if let detailJSON = result {
                        jsonResults.append(detailJSON["data"]["vsHistoryDetail"])
                    }
                }
                do {
                    if !jsonResults.isEmpty {
                        try await SplatDatabase.shared.insertBattles(jsons: jsonResults)
                        await BattleListViewModel.shared.loadBattles()
                    }
                } catch {
                    logError(error)
                }
                return jsonResults.count
            }
        }
        
    }
    
    func fetchRecords(isFetching: TaskLocal<Bool>,
                      refreshInterval: Int,
                      lastRefreshTime: inout Int,
                      icon: ImageResource,
                      fetchValidIds: () async throws -> [String],
                      fetchDetails: ([String]) async throws -> Int
    ) async {
        guard !isFetching.get() && 
              lastRefreshTime + refreshInterval <= Int(Date().timeIntervalSince1970) else {
            return
        }
        
        await isFetching.withValue(true) {
            let maxRetries = 1
            var retryCount = 0
            
            while retryCount < maxRetries {
                do {
                    try await setToken()
                    let validIds = try await fetchValidIds()
                    
                    guard !validIds.isEmpty else {
                        Indicators.shared.display(.init(icon: .image(Image(icon)),
                                                      title: "无新纪录",
                                                      dismissType: .after(2)))
                        lastRefreshTime = Int(Date().timeIntervalSince1970)
                        return
                    }
                    
                    let progress = Progress(totalUnitCount: Int64(validIds.count))
                    Indicators.shared.display(.init(icon: .progressIndicator,
                                                  title: "加载\(validIds.count)项纪录",
                                                  dismissType: .after(5)))
                    
                    let recordCount = try await fetchDetails(validIds)
                    
                    lastRefreshTime = Int(Date().timeIntervalSince1970)
                    Indicators.shared.display(.init(icon: .success,
                                                  title: "已加载\(recordCount)项纪录",
                                                  dismissType: .after(3)))
                    return
                    
                } catch SN3Client.Error.invalidGameServiceToken {
                    await NSOAccountManager.shared.refreshGameServiceTokenManual()
                    retryCount += 1
                } catch {
                    let errorMessage = "第\(retryCount + 1)次尝试失败: \(error.localizedDescription)"
                    Indicators.shared.display(.init(icon: .systemImage("xmark.seal"),
                                                  title: "加载失败",
                                                  expandedText: errorMessage,
                                                  dismissType: .automatic,
                                                  style: .error))
                    logError(error)
                    retryCount += 1
                }
            }
            
            if retryCount >= maxRetries {
                Indicators.shared.display(.init(icon: .systemImage("xmark.seal"),
                                              title: "达到最大重试次数",
                                              expandedText: "请稍后再试",
                                              dismissType: .automatic,
                                              style: .error))
            }
        }
    }
    
    func setToken() async throws {
        await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
        guard let gameServiceToken = AppUserDefaults.shared.gameServiceToken else{ return }
        try await setToken(gameServiceToken)
    }
    
    func fetchHistoryRecord() async -> HistoryRecord? {
        return await fetchRecord(.historyRecord, resultType: HistoryRecord.self)
    }
    
    func fetchCoopRecord() async -> CoopRecord? {
        return await fetchRecord(.coopRecord, resultType: CoopRecord.self)
    }
    
    func fetchWeaponRecords() async -> WeaponRecords? {
        return await fetchRecord(.weaponRecord, resultType: WeaponRecords.self)
    }

    func fetchStageRecord() async -> [StageRecord] {
        return await fetchRecord(.stageRecord, resultType: [StageRecord].self) ?? []
    }

    func fetchRecord<T: SwiftyJSONDecodable>(_ queryType: any SN3PersistedQuery,
                                            resultType: T.Type,
                                            maxRetries: Int = 3) async -> T? {
        var retryCount = 0
        
        while retryCount < maxRetries {
            do {
                try await setToken()
                let data = try await JSON(data: self.graphQL(queryType))
                
                if retryCount > 0 {
                    Indicators.shared.display(.init(icon: .success,
                                                  title: "重试成功",
                                                  dismissType: .after(3)))
                }
                
                return T(json: data)
                
            } catch SN3Client.Error.invalidGameServiceToken {
                await NSOAccountManager.shared.refreshGameServiceTokenManual()
                retryCount += 1
            } catch {
                logError(error)
                retryCount += 1
                
                if retryCount < maxRetries {
                    Indicators.shared.display(.init(icon: .systemImage("arrow.clockwise"),
                                                  title: "重试中...",
                                                  expandedText: "第\(retryCount)次重试",
                                                  dismissType: .after(2)))
                    try? await Task.sleep(nanoseconds: UInt64(1 * Double(NSEC_PER_SEC)))
                }
            }
        }
        
        Indicators.shared.display(.init(icon: .systemImage("xmark.seal"),
                                      title: "获取数据失败",
                                      expandedText: "请稍后再试",
                                      dismissType: .automatic,
                                      style: .error))
        return nil
    }
}

extension Array:SwiftyJSONDecodable where Element == StageRecord {
    init(json: JSON) {
        self = json["data"]["stageRecords"]["nodes"].arrayValue.map { StageRecord(json: $0) }
    }
}

