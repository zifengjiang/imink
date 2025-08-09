import Foundation
import SplatDatabase
import SwiftyJSON
import Combine
import GRDB

class NSOAccountManager:ObservableObject {
    static let shared = NSOAccountManager()

    @Published var isLogin:Bool = AppUserDefaults.shared.sessionToken != nil
    @Published var accountId:Int? = AppUserDefaults.shared.accountId

    func refreshGameServiceTokenIfNeeded() async {
        if let sessionToken = AppUserDefaults.shared.sessionToken, AppUserDefaults.shared.gameServiceTokenRefreshTime + 1800 < Int(Date().timeIntervalSince1970){
            let IndicatorId = UUID().uuidString
            do{
                Indicators.shared.display(Indicator(id: IndicatorId, icon: .progressIndicator, title: "刷新游戏服务令牌", subtitle: "请稍候...", dismissType: .manual, isUserDismissible: false))
                try await refreshGameServiceToken(sessionToken: sessionToken)
                Indicators.shared.updateSubtitle(for: IndicatorId, subtitle: "刷新成功")

            }catch{
                logError(error)
                Indicators.shared.updateSubtitle(for: IndicatorId, subtitle: "刷新失败，请稍后重试")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                Indicators.shared.dismiss(with: IndicatorId)
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

    private func refreshGameServiceToken(sessionToken: String) async throws {
        let gameServiceToken = try await NSOAuthorization.shared.requestWebServiceToken(sessionToken:sessionToken).result.accessToken
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
