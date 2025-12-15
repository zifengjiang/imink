import Foundation
import SwiftUI
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
        
        // 使用全局任务组ID，所有任务共享同一个indicator
        let groupId = Indicators.globalTaskGroupId
        let loginIndicatorId = await Indicators.shared.acquireSharedIndicator(
            groupId: groupId,
            title: "登录中",
            icon: .progressIndicator
        )
        
        // 注意：不在defer中完成任务组，因为如果登录成功，会在正常流程中完成
        // 如果登录失败，会在catch中完成
        
        do {
            // 注册第一个子任务
            await Indicators.shared.registerSubTask(groupId: groupId, taskName: "登录-获取sessionToken")
            
            // 使用新的loginFlow方法，参考api.ts的实现
            let loginFlowResult = try await NSOAuthorization.shared.loginFlow(indicatorId: loginIndicatorId)
            
            await Indicators.shared.completeSubTask(groupId: groupId, taskName: "登录-获取sessionToken")
            await Indicators.shared.registerSubTask(groupId: groupId, taskName: "登录-设置游戏服务令牌")
            try await SN3Client.shared.setToken(loginFlowResult.webServiceToken.result.accessToken)
            
            await Indicators.shared.completeSubTask(groupId: groupId, taskName: "登录-设置游戏服务令牌")
            await Indicators.shared.registerSubTask(groupId: groupId, taskName: "登录-获取账户ID")
            let sp3PrincipalId = try await getAccountId()?.extractUserId()
            
            await Indicators.shared.completeSubTask(groupId: groupId, taskName: "登录-获取账户ID")
            await Indicators.shared.registerSubTask(groupId: groupId, taskName: "登录-下载头像")
            let avatar = loginFlowResult.loginResult.result.user.imageUri
            let avatarData = try await downLoadImageData(url: URL(string: avatar)!)
            
            await Indicators.shared.completeSubTask(groupId: groupId, taskName: "登录-下载头像")
            await Indicators.shared.registerSubTask(groupId: groupId, taskName: "登录-保存账户信息")
            let account = Account(sp3Id: sp3PrincipalId, avatar: avatarData, name: loginFlowResult.loginResult.result.user.name, code: loginFlowResult.loginResult.result.user.friendCode, sessionToken: loginFlowResult.sessionToken, lastRefresh: Date())
            try updateORInsertAccount(account)
            
            let accountId = (try await SplatDatabase.shared.dbQueue.read { db in
                return try Account.filter(Column("sp3Id") == sp3PrincipalId).fetchOne(db)?.id
            })!
            
            await Indicators.shared.completeSubTask(groupId: groupId, taskName: "登录-保存账户信息")
            
            DispatchQueue.main.async {
                self.status = .loginSuccess
                MainViewModel.shared.isLogin = true
                AppUserDefaults.shared.sessionToken = loginFlowResult.sessionToken
                AppUserDefaults.shared.accountId = Int(accountId)
                AppUserDefaults.shared.gameServiceToken = loginFlowResult.webServiceToken.result.accessToken
                AppUserDefaults.shared.gameServiceTokenRefreshTime = Int(Date().timeIntervalSince1970)
            }
            
            // 完成任务组（只有在没有其他活跃任务时才真正完成）
            await Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: "登录成功")
        } catch {
            logError(error)
            // 完成任务组（只有在没有其他活跃任务时才真正完成）
            await Indicators.shared.completeTaskGroup(groupId: groupId, success: false, message: "登录失败：请检查网络连接或重试")
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


