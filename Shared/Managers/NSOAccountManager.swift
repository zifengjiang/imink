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
            // 使用全局任务组ID，所有任务共享同一个indicator
            let groupId = Indicators.globalTaskGroupId
            let indicatorId = await Indicators.shared.acquireSharedIndicator(
                groupId: groupId,
                title: "刷新游戏服务令牌",
                icon: .progressIndicator
            )
            
            do{
                // 注册子任务
                await Indicators.shared.registerSubTask(groupId: groupId, taskName: "刷新令牌-刷新游戏服务令牌")
                
                try await refreshGameServiceToken(sessionToken: sessionToken, indicatorId: indicatorId)
                
                // 完成子任务
                await Indicators.shared.completeSubTask(groupId: groupId, taskName: "刷新令牌-刷新游戏服务令牌")
                
                // 完成任务组（只有在没有其他活跃任务时才真正完成）
                await Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: "刷新游戏服务令牌成功")

            }catch{
                logError(error)
                // 完成子任务
                await Indicators.shared.completeSubTask(groupId: groupId, taskName: "刷新令牌-刷新游戏服务令牌")
                // 完成任务组（只有在没有其他活跃任务时才真正完成）
                await Indicators.shared.completeTaskGroup(groupId: groupId, success: false, message: "刷新游戏服务令牌失败")
            }
        }
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
