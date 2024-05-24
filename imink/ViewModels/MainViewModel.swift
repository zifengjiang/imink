import Foundation
import SplatDatabase
import Combine
import SplatNet3API
import SwiftyJSON


class MainViewModel: ObservableObject {
    static let shared = MainViewModel()

    @Published var isLogin: Bool = AppUserDefaults.shared.sessionToken != nil

    private var cancelBag = Set<AnyCancellable>()
    init() {
        let currentLanguage = AppUserDefaults.shared.currentLanguage
        if let code = Bundle.main.preferredLocalizations.last {
            if code != currentLanguage {
                AppUserDefaults.shared.currentLanguage = code
            }
        }
    }

    func loadCoop() async throws {
        if let sessionToken = AppUserDefaults.shared.sessionToken{
            print(sessionToken)
            let gameServiceToken = try await NSOAuthorization.shared.requestWebServiceToken(sessionToken:sessionToken).result.accessToken
            try await SN3Client.shared.setToken(gameServiceToken)

            let coopHistory = try await JSON(data: SN3Client.shared.graphQL(.coopHistory))
            let coops = coopHistory["data"]["coopResult"]["historyGroups"]["nodes"].arrayValue.flatMap { nodeJSON in
                return nodeJSON["historyDetails"]["nodes"].arrayValue.map { detailJSON in
                    return detailJSON
                }
            }
            print(coops.count)
            for coop in coops{
                let coopId = coop["id"].stringValue
                if try SplatDatabase.shared.isCoopExist(id: coopId,db: nil){
                    print("\(coopId) exist")
                    continue
                }
                let coopJSON = try await JSON(data: SN3Client.shared.graphQL(.coopHistoryDetail(id: coopId)))
                try SplatDatabase.shared.insertCoop(json: coopJSON["data"]["coopHistoryDetail"])
                print("insert coop")
            }
        }
    }
}
