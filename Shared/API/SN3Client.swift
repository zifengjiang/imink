import Foundation
import SplatDatabase
import SwiftyJSON
import SplatNet3API
import os.log
import IndicatorsKit
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
    static let isFetchingCoops = TaskLocal<Bool>(wrappedValue: false)
    static let isFetchingBattles = TaskLocal<Bool>(wrappedValue: false)
}

extension SN3Client {
    static let isFetchingCoops = TaskLocal<Bool>(wrappedValue: false)
    func fetchCoops() async {
        await abstractFetch(isFetching: .isFetchingCoops, refreshInterval: 300, lastRefreshTime: &AppUserDefaults.shared.coopsRefreshTime,icon: .salmonRun) {
            let coopHistory = try await JSON(data: self.graphQL(.coopHistory))
            let ids = coopHistory["data"]["coopResult"]["historyGroups"]["nodes"].arrayValue.flatMap { nodeJSON in
                return nodeJSON["historyDetails"]["nodes"].arrayValue.map { detailJSON in
                    return detailJSON["id"].stringValue
                }
            }
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
        await abstractFetch(isFetching: .isFetchingBattles, refreshInterval: 10, lastRefreshTime: &AppUserDefaults.shared.battlesRefreshTime,icon: .regularBattle) {
            try await withThrowingTaskGroup(of: JSON?.self) { group in
                var ids: [String] = []
                group.addTask {
                    return try JSON(data:await self.graphQL(.latestBattleHistories))
                }

                group.addTask {
                    return try JSON(data:await self.graphQL(.regularBattleHistories))
                }

                group.addTask {
                    return try JSON(data:await self.graphQL(.bankaraBattleHistories))
                }

                group.addTask {
                    return try JSON(data:await self.graphQL(.privateBattleHistories))
                }

                group.addTask {
                    return try JSON(data:await self.graphQL(.eventBattleHistories))
                }

                group.addTask {
                    return try JSON(data:await self.graphQL(.xBattleHistories))
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

    func abstractFetch(isFetching: TaskLocal<Bool>,
                       refreshInterval: Int,
                       lastRefreshTime: inout Int,
                       icon: ImageResource,
                       fetchValidIds: () async throws -> [String],
                       fetchDetails: ([String]) async throws -> Int
    ) async {
        if isFetching.get() || lastRefreshTime + refreshInterval > Int(Date().timeIntervalSince1970){
            return
        }

        await isFetching.withValue(true) {
            do{
                let indicatorId = UUID().uuidString
                await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
                guard let gameServiceToken = AppUserDefaults.shared.gameServiceToken else{ return }
                try await SN3Client.shared.setToken(gameServiceToken)
                let validIds = try await fetchValidIds()
                if validIds.isEmpty {
                    Indicators.shared.display(.init(id: indicatorId, icon: .image(Image(icon)),title: "无新纪录", dismissType: .after(2)))
                    lastRefreshTime = Int(Date().timeIntervalSince1970)
                    return
                }
                Indicators.shared.display(.init(id: indicatorId, icon: .progressIndicator,title: "加载\(validIds.count)项纪录",dismissType: .after(5)))
                let recordCount = try await fetchDetails(validIds)
                Indicators.shared.display(.init(id: "成功加载", icon: .systemImage("checkmark.seal"),title: "已加载\(recordCount)项纪录", dismissType: .after(3)))
                lastRefreshTime = Int(Date().timeIntervalSince1970)
            }catch SN3Client.Error.invalidGameServiceToken{
                await NSOAccountManager.shared.refreshGameServiceTokenManual()
            } catch{
                Indicators.shared.display(.init(id: UUID().uuidString, icon: .systemImage("xmark.seal"),title: "加载失败",expandedText: error.localizedDescription, dismissType: .automatic, style: .error))
                logError(error)
            }
        }
    }

    func fetchHistoryRecord() async {
        do {
            print("fetchHistoryRecord")
            let historyRecord = try await JSON(data: self.graphQL(.historyRecord))
            print(historyRecord)
        }catch{
            logError(error)
        }
    }

    func fetchCoopRecord() async -> CoopRecord? {
        do {
            let record = try await JSON(data: self.graphQL(.coopRecord))
            return CoopRecord(json: record)
        }catch{
            logError(error)
            return nil
        }
    }
}


