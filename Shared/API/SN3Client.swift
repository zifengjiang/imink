import Foundation
import SplatDatabase
import SwiftyJSON
import SplatNet3API
import os.log
import IndicatorsKit
import SwiftUI

extension SN3Client {
    func fetchCoops() async {
        let indicatorId = UUID().uuidString
        do{
            await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
            guard let gameServiceToken = AppUserDefaults.shared.gameServiceToken else{ return }

            try await SN3Client.shared.setToken(gameServiceToken)
            let coopHistory = try await JSON(data: self.graphQL(.coopHistory))
            let ids = coopHistory["data"]["coopResult"]["historyGroups"]["nodes"].arrayValue.flatMap { nodeJSON in
                return nodeJSON["historyDetails"]["nodes"].arrayValue.map { detailJSON in
                    return detailJSON["id"].stringValue
                }
            }

            let validIds = try SplatDatabase.shared.filterNotExistsCoop(ids: ids).prefix(3)

            if validIds.isEmpty {
                Indicators.shared.display(.init(id: indicatorId, icon: .image(Image(.salmonRun)),title: "无新纪录", dismissType: .after(2)))
                return
            }
            Indicators.shared.display(.init(id: indicatorId, icon: .progressIndicator,title: "加载\(validIds.count)项纪录",dismissType: .manual))


            await withTaskGroup(of: JSON?.self) { group in
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
                Indicators.shared.dismiss(with: indicatorId)
                Indicators.shared.display(.init(id: "成功加载", icon: .systemImage("checkmark.seal"),title: "已加载\(validIds.count)项纪录", dismissType: .after(3)))
//                DispatchQueue.main.asyncAfter(deadline: .now()+2){
//                    Indicators.shared.dismiss(with: "成功加载")
//                }
            }
        }catch SN3Client.Error.invalidGameServiceToken{
            Indicators.shared.display(.init(id: UUID().uuidString, icon: .systemImage("xmark.seal"),title: "加载失败",expandedText: "invalidGameServiceToken", dismissType: .automatic, style: .error))
        }catch{
            Indicators.shared.dismiss(with: indicatorId)
            Indicators.shared.display(.init(id: UUID().uuidString, icon: .systemImage("xmark.seal"),title: "加载失败",expandedText: error.localizedDescription, dismissType: .automatic, style: .error))
            logError(error)
        }
    }
}



