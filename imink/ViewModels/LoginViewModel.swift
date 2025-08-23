import Foundation
import SwiftUICore
import SwiftyJSON
import Combine
import SplatDatabase
import GRDB

@MainActor
class LoginViewModel:ObservableObject{
    enum Status {
        case none
        case loading
        case loginSuccess
    }

    @Published var status: Status = .none

    var cancelBag = Set<AnyCancellable>()

    func loginFlow() async {
        DispatchQueue.main.async {
            self.status = .loading
        }
        
        let loginIndicatorId = UUID().uuidString
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                Indicators.shared.dismiss(with: loginIndicatorId)
            }
        }
        
        do {
            Indicators.shared.display(Indicator(id: loginIndicatorId, icon: .progressIndicator, title: "登录中", subtitle: "获取sessionToken", dismissType: .manual, isUserDismissible: false))
            
            // 使用新的loginFlow方法，参考api.ts的实现
            let loginFlowResult = try await NSOAuthorization.shared.loginFlow(indicatorId: loginIndicatorId)
            
            Indicators.shared.updateSubtitle(for: loginIndicatorId, subtitle: "设置游戏服务令牌")
            try await SN3Client.shared.setToken(loginFlowResult.webServiceToken.result.accessToken)
            
            Indicators.shared.updateSubtitle(for: loginIndicatorId, subtitle: "获取账户ID")
            let sp3PrincipalId = try await getAccountId()?.extractUserId()
            
            Indicators.shared.updateSubtitle(for: loginIndicatorId, subtitle: "下载头像")
            let avatar = loginFlowResult.loginResult.result.user.imageUri
            let avatarData = try await downLoadImageData(url: URL(string: avatar)!)
            
            Indicators.shared.updateSubtitle(for: loginIndicatorId, subtitle: "保存账户信息")
            let account = Account(sp3Id: sp3PrincipalId, avatar: avatarData, name: loginFlowResult.loginResult.result.user.name, code: loginFlowResult.loginResult.result.user.friendCode, sessionToken: loginFlowResult.sessionToken, lastRefresh: Date())
            try updateORInsertAccount(account)
            
            let accountId = (try await SplatDatabase.shared.dbQueue.read { db in
                return try Account.filter(Column("sp3Id") == sp3PrincipalId).fetchOne(db)?.id
            })!
            
            Indicators.shared.updateTitle(for: loginIndicatorId, title: "登录成功")
            Indicators.shared.updateSubtitle(for: loginIndicatorId, subtitle: "正在完成登录...")
            Indicators.shared.updateIcon(for: loginIndicatorId, icon: .success)
            
            DispatchQueue.main.async {
                self.status = .loginSuccess
                MainViewModel.shared.isLogin = true
                AppUserDefaults.shared.sessionToken = loginFlowResult.sessionToken
                AppUserDefaults.shared.accountId = Int(accountId)
                AppUserDefaults.shared.gameServiceToken = loginFlowResult.webServiceToken.result.accessToken
                AppUserDefaults.shared.gameServiceTokenRefreshTime = Int(Date().timeIntervalSince1970)
            }
        } catch {
            logError(error)
            Indicators.shared.updateTitle(for: loginIndicatorId, title: "登录失败")
            Indicators.shared.updateSubtitle(for: loginIndicatorId, subtitle: "请检查网络连接或重试")
            Indicators.shared.updateIcon(for: loginIndicatorId, icon: .image(Image(systemName: "xmark.icloud")))
        }
    }

    private func updateORInsertAccount(_ newAccount: Account) throws {
        try SplatDatabase.shared.dbQueue.write { db in
            if var existingAccount = try Account.filter(Column("sp3Id") == newAccount.sp3Id).fetchOne(db) {
                    // 更新现有记录
                existingAccount.avatar = newAccount.avatar
                existingAccount.name = newAccount.name
                existingAccount.code = newAccount.code
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


