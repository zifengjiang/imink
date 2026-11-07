import Foundation
import SwiftUI
import SwiftyJSON
import Combine
import SplatDatabase
import GRDB

enum SessionTokenLoginInput {
    static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
class LoginViewModel:ObservableObject{
    enum Status {
        case none
        case loading
        case loginSuccess
    }

    @Published var status: Status = .none
    @Published var errorMessage: String?

    var cancelBag = Set<AnyCancellable>()

    /// 把底层错误转成用户可以看懂的提示，避免所有失败都显示同一句笼统文案。
    private static func describe(_ error: Error) -> String {
        switch error {
        case let error as NSOAuthorization.NSOAuthError:
            return error.errorDescription ?? "\(error)"
        case let error as SN3Client.Error:
            return error.errorDescription ?? "\(error)"
        case is URLError:
            return "网络请求失败：\(error.localizedDescription)"
        default:
            return "登录失败：\(error.localizedDescription)"
        }
    }

    func loginFlow() async {
        errorMessage = nil
        status = .loading

        let loginIndicatorId = UUID().uuidString
        defer {
            Indicators.shared.dismiss(with: loginIndicatorId)
        }
        
        do {
            Toast.progress(id: loginIndicatorId, title: "登录中", subtitle: "获取sessionToken")
            
            // 使用新的loginFlow方法，参考api.ts的实现
            let loginFlowResult = try await NSOAuthorization.shared.loginFlow(indicatorId: loginIndicatorId)
            
            Toast.update(id: loginIndicatorId, subtitle: "设置游戏服务令牌")
            try await SN3Client.shared.setToken(loginFlowResult.webServiceToken.result.accessToken)
            
            Toast.update(id: loginIndicatorId, subtitle: "获取账户ID")
            let sp3PrincipalId = try await getAccountId()?.extractUserId()
            
            Toast.update(id: loginIndicatorId, subtitle: "下载头像")
            let avatar = loginFlowResult.loginResult.result.user.imageUri
            let avatarData = try await downLoadImageData(url: URL(string: avatar)!)
            
            Toast.update(id: loginIndicatorId, subtitle: "保存账户信息")
            let account = Account(sp3Id: sp3PrincipalId, avatar: avatarData, name: loginFlowResult.loginResult.result.user.name, code: loginFlowResult.loginResult.result.user.friendCode, sessionToken: loginFlowResult.sessionToken, lastRefresh: Date())
            try updateORInsertAccount(account)
            
            let accountId = (try await SplatDatabase.shared.dbQueue.read { db in
                return try Account.filter(Column("sp3Id") == sp3PrincipalId).fetchOne(db)?.id
            })!
            
            Toast.finish(id: loginIndicatorId, title: "登录成功")
            Toast.update(id: loginIndicatorId, subtitle: "正在完成登录...")

            status = .loginSuccess
            MainViewModel.shared.isLogin = true
            AppUserDefaults.shared.sessionToken = loginFlowResult.sessionToken
            AppUserDefaults.shared.useManualGameServiceToken = false
            AppUserDefaults.shared.manualGameServiceToken = nil
            AppUserDefaults.shared.accountId = Int(accountId)
            AppUserDefaults.shared.gameServiceToken = loginFlowResult.webServiceToken.result.accessToken
            AppUserDefaults.shared.gameServiceTokenRefreshTime = Int(Date().timeIntervalSince1970)
        } catch {
            logError(error)
            status = .none
            let message = Self.describe(error)
            errorMessage = message
            Toast.finish(id: loginIndicatorId, title: "登录失败", failed: true)
            Toast.update(id: loginIndicatorId, subtitle: message)
        }
    }

    func loginWithSessionToken(_ rawSessionToken: String) async {
        guard let sessionToken = SessionTokenLoginInput.normalized(rawSessionToken) else {
            errorMessage = "请输入 session token"
            return
        }

        status = .loading
        errorMessage = nil

        let loginIndicatorId = UUID().uuidString
        defer {
            Indicators.shared.dismiss(with: loginIndicatorId)
        }

        do {
            Toast.progress(id: loginIndicatorId, title: "登录中", subtitle: "验证 session token")

            let webServiceToken = try await NSOAuthorization.shared.requestWebServiceToken(
                sessionToken: sessionToken,
                indicatorID: loginIndicatorId
            )

            Toast.update(id: loginIndicatorId, subtitle: "设置游戏服务令牌")
            try await SN3Client.shared.setToken(webServiceToken.result.accessToken)

            Toast.update(id: loginIndicatorId, subtitle: "获取账户ID")
            guard let sp3PrincipalId = try await getAccountId()?.extractUserId(), !sp3PrincipalId.isEmpty else {
                throw NSOAuthorization.NSOAuthError.nxapiError(message: "Failed to resolve SplatNet account id")
            }

            Toast.update(id: loginIndicatorId, subtitle: "保存账户信息")
            let account = Account(
                sp3Id: sp3PrincipalId,
                sessionToken: sessionToken,
                lastRefresh: Date()
            )
            try updateORInsertAccount(account)

            let accountId = try await SplatDatabase.shared.dbQueue.read { db in
                try Account.filter(Column("sp3Id") == sp3PrincipalId).fetchOne(db)?.id
            }

            guard let accountId else {
                throw NSOAuthorization.NSOAuthError.nxapiError(message: "Failed to persist account")
            }

            Toast.finish(id: loginIndicatorId, title: "登录成功")
            Toast.update(id: loginIndicatorId, subtitle: "正在完成登录...")

            status = .loginSuccess
            MainViewModel.shared.isLogin = true
            AppUserDefaults.shared.sessionToken = sessionToken
            AppUserDefaults.shared.useManualGameServiceToken = false
            AppUserDefaults.shared.manualGameServiceToken = nil
            AppUserDefaults.shared.accountId = Int(accountId)
            AppUserDefaults.shared.gameServiceToken = webServiceToken.result.accessToken
            AppUserDefaults.shared.gameServiceTokenRefreshTime = Int(Date().timeIntervalSince1970)
        } catch {
            logError(error)
            status = .none
            errorMessage = Self.describe(error)
            Toast.finish(id: loginIndicatorId, title: "登录失败", failed: true)
            Toast.update(id: loginIndicatorId, subtitle: "请检查 session token 后重试")
            Indicators.shared.updateIcon(for: loginIndicatorId, icon: .image(Image(systemName: "xmark.icloud")))
        }
    }

    private func updateORInsertAccount(_ newAccount: Account) throws {
        try SplatDatabase.shared.dbQueue.write { db in
            if var existingAccount = try Account.filter(Column("sp3Id") == newAccount.sp3Id).fetchOne(db) {
                    // 更新现有记录
                existingAccount.avatar = newAccount.avatar ?? existingAccount.avatar
                existingAccount.name = newAccount.name ?? existingAccount.name
                existingAccount.code = newAccount.code ?? existingAccount.code
                existingAccount.sessionToken = newAccount.sessionToken
                existingAccount.lastRefresh = newAccount.lastRefresh
                try existingAccount.update(db)
            } else {
                    // 插入新记录
                try newAccount.insert(db)
            }
        }
    }

    private func downLoadImageData(url:URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    private func getAccountId() async throws -> String?{
        let battleJSON = try JSON(data:try await SN3Client.shared.graphQL(.latestBattleHistories))
        var accountId:String? = nil
        if let id = battleJSON["data"]["latestBattleHistories"]["historyGroupsOnlyFirst"]["nodes"].arrayValue.first?["historyDetails"]["nodes"].arrayValue.first?["player"]["id"].stringValue{
            accountId = id
        }else{
            let coopJSON = try JSON(data:try await SN3Client.shared.graphQL(.coopHistory))
            if let id = coopJSON["data"]["coopResult"]["historyGroupsOnlyFirst"]["nodes"].arrayValue.first?["historyDetails"]["nodes"].arrayValue.first?["id"].stringValue{
                accountId = id
            }
        }
        return accountId
    }
}
