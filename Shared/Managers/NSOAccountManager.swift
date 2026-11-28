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
        // 如果使用手动输入的token，则不自动刷新
        guard !AppUserDefaults.shared.useManualGameServiceToken else { return }
        
        if let sessionToken = AppUserDefaults.shared.sessionToken, AppUserDefaults.shared.gameServiceTokenRefreshTime + 3600 < Int(Date().timeIntervalSince1970){
            let IndicatorId = UUID().uuidString
            defer{
                Indicators.shared.dismiss(with: IndicatorId)
            }
            do{
                Toast.progress(id: IndicatorId, title: "刷新游戏服务令牌")
                try await refreshGameServiceToken(sessionToken: sessionToken, indicatorId: IndicatorId)
                Toast.finish(id: IndicatorId, title: "刷新游戏服务令牌成功")

            }catch{
                logError(error)
                Toast.finish(id: IndicatorId, title: "刷新游戏服务令牌失败", failed: true)
            }
        }
    }

    /// 保证手上有一个可用的游戏服务令牌，拿不到就**抛错**。
    ///
    /// 以前 `ensureToken()` 里直接不调用刷新（那行被注释掉了），而拿不到 `gameServiceToken`
    /// 时 `makeBullet()` 又只是静默 `return`，于是 splatnet3 的请求会**不带 Authorization**
    /// 发出去——服务端对这种请求回应的是「HTTP 400 + 空 body」，看起来像“同步完成但没数据”。
    func ensureGameServiceToken() async throws -> String {
        if AppUserDefaults.shared.useManualGameServiceToken,
           let manual = AppUserDefaults.shared.manualGameServiceToken,
           !manual.isEmpty {
            return manual
        }

        guard let sessionToken = AppUserDefaults.shared.sessionToken, !sessionToken.isEmpty else {
            throw NSOAuthorization.NSOAuthError.invalidSessionToken
        }

        let needsRefresh = AppUserDefaults.shared.gameServiceTokenRefreshTime + 3600
            < Int(Date().timeIntervalSince1970)
        if !needsRefresh, let token = AppUserDefaults.shared.gameServiceToken, !token.isEmpty {
            return token
        }

        try await refreshGameServiceToken(sessionToken: sessionToken)

        guard let token = AppUserDefaults.shared.gameServiceToken, !token.isEmpty else {
            throw SN3Client.Error.missingGameServiceToken
        }
        return token
    }

    func refreshGameServiceTokenManual(indicatorId: String? = nil) async throws{
        if let sessionToken = AppUserDefaults.shared.sessionToken{
            try await refreshGameServiceToken(sessionToken: sessionToken, indicatorId: indicatorId)
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
