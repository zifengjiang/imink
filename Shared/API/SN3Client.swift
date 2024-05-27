import Foundation
import SplatDatabase
import SwiftyJSON
import SplatNet3API
import os.log

extension SN3Client {
    func fetchCoops() async {
        do{
            if let gameServiceToken = AppUserDefaults.shared.gameServiceToken{
                try await SN3Client.shared.setToken(gameServiceToken)
                let coopHistory = try await JSON(data: self.graphQL(.coopHistory))
                let ids = coopHistory["data"]["coopResult"]["historyGroups"]["nodes"].arrayValue.flatMap { nodeJSON in
                    return nodeJSON["historyDetails"]["nodes"].arrayValue.map { detailJSON in
                        return detailJSON["id"].stringValue
                    }
                }

                let validIds = try SplatDatabase.shared.filterNotExistsCoop(ids: ids)

                await withTaskGroup(of: JSON?.self) { group in
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
                    for await result in group{
                        if let detailJSON = result{
                            do{
                                try SplatDatabase.shared.insertCoop(json: detailJSON["data"]["coopHistoryDetail"])
                            }catch{
                                logError(error)
                            }
                        }
                    }
                }
            }
        }catch SN3Client.Error.invalidGameServiceToken{
//            try await refreshGameServiceToken()
            await fetchCoops()
        }catch{
            logError(error)
        }
    }
}



