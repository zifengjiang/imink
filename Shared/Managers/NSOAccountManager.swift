import Foundation
import SplatDatabase
import SwiftyJSON
import Combine
import GRDB
import SwiftUI

class NSOAccountManager:ObservableObject {
    static let shared = NSOAccountManager()

    @Published var isLogin:Bool = AppUserDefaults.shared.sessionToken != nil
    @Published var accountId:Int? = AppUserDefaults.shared.accountId

    func refreshGameServiceTokenIfNeeded() async {
        if let sessionToken = AppUserDefaults.shared.sessionToken, AppUserDefaults.shared.gameServiceTokenRefreshTime + 3600 < Int(Date().timeIntervalSince1970){
            let IndicatorId = UUID().uuidString
            defer{
                Indicators.shared.dismiss(with: IndicatorId)
            }
            do{
                Indicators.shared.display(Indicator(id: IndicatorId, icon: .progressIndicator, title: "刷新游戏服务令牌", dismissType: .manual, isUserDismissible: false))
                try await refreshGameServiceToken(sessionToken: sessionToken, indicatorId: IndicatorId)
                Indicators.shared.updateTitle(for: IndicatorId, title: "刷新游戏服务令牌成功")
                Indicators.shared.updateIcon(for: IndicatorId, icon: .success)

            }catch{
                logError(error)
                Indicators.shared.updateTitle(for: IndicatorId, title: "刷新游戏服务令牌失败")
                Indicators.shared.updateIcon(for: IndicatorId, icon: .image(Image(systemName: "xmark.icloud")))
            }
        }
    }

    func refreshGameServiceTokenManual() async {
        if let sessionToken = AppUserDefaults.shared.sessionToken{
            do{
                try await refreshGameServiceToken(sessionToken: sessionToken)
            }catch{
                logError(error)
            }
        }
    }

    private func refreshGameServiceToken(sessionToken: String, indicatorId: String? = nil) async throws {
        let gameServiceToken = try await NSOAuthorization.shared.requestWebServiceToken(sessionToken:sessionToken, indicatorID: indicatorId).result.accessToken
        AppUserDefaults.shared.gameServiceToken = gameServiceToken
        AppUserDefaults.shared.gameServiceTokenRefreshTime = Int(Date().timeIntervalSince1970)
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
