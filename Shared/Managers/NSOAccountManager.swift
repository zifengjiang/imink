import Foundation
import SplatDatabase
import SwiftyJSON
import SplatNet3API
import Combine
import GRDB

class NSOAccountManager:ObservableObject {
    static let shared = NSOAccountManager()

    @Published var isLogin:Bool = AppUserDefaults.shared.sessionToken != nil
    @Published var accountId:Int? = AppUserDefaults.shared.accountId

    func refreshGameServiceTokenIfNeeded() async {
        if let sessionToken = AppUserDefaults.shared.sessionToken, AppUserDefaults.shared.gameServiceTokenRefreshTime < Int(Date().timeIntervalSince1970){
            do{
                let gameServiceToken = try await NSOAuthorization.shared.requestWebServiceToken(sessionToken:sessionToken).result.accessToken
                AppUserDefaults.shared.gameServiceToken = gameServiceToken
                AppUserDefaults.shared.gameServiceTokenRefreshTime = Int(Date().timeIntervalSince1970)
            }catch{
                logError(error)
            }
        }
    }
}

extension SplatDatabase {
    func accounts() -> AnyPublisher<[Account], Error> {
        return ValueObservation
            .tracking(
                Account
                    .filter(Column("sessionToken") != nil)
                    .fetchAll
            )
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}
