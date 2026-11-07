import Foundation
import SplatDatabase
import SwiftyJSON
import os.log
import SwiftUI

    // MARK: - Logging helpers
@inline(__always)
private func logError(_ error: any Error, _ message: StaticString = "❌ Error") {
    os_log(message, type: .error, String(describing: error))
}

    // MARK: - Task-local flags (fetch guards)
extension TaskLocal where Value == Bool {
    static let isFetchingCoops = TaskLocal<Bool>(wrappedValue: false)
    static let isFetchingBattles = TaskLocal<Bool>(wrappedValue: false)
}

    // MARK: - Utilities
private enum Gate {
    static func shouldProceed(last: Int, interval: Int, now: Int = Int(Date().timeIntervalSince1970)) -> Bool {
        return last + interval <= now
    }
}


    // MARK: - SN3Client token helper
extension SN3Client {
    func ensureToken() async throws {
            //        await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
        
        // 优先使用手动输入的token
        if AppUserDefaults.shared.useManualGameServiceToken, 
           let manualToken = AppUserDefaults.shared.manualGameServiceToken,
           !manualToken.isEmpty {
            try await setToken(manualToken)
        } else if let token = AppUserDefaults.shared.gameServiceToken {
            try await setToken(token)
        }
    }
}

    // MARK: - Generic fetch pipeline
extension SN3Client {
    @discardableResult
    func runPipeline(
        flag: TaskLocal<Bool>,
        refreshInterval: Int,
        lastRefreshTime: inout Int,
        icon: ImageResource,
        getValidIDs: @escaping () async throws -> [String],
        fetchAndStoreDetails: @escaping ([String]) async throws -> Int,
        groupId: String? = nil,  // 可选的任务组ID
        taskName: String? = nil  // 可选的子任务名称
    ) async -> Int?{
        guard !flag.get(), Gate.shouldProceed(last: lastRefreshTime, interval: refreshInterval) else { return nil}
        
        let IndicatorID: String
        let useTaskGroup: Bool
        
        // 如果提供了 groupId，使用任务组管理
        if let groupId = groupId {
            useTaskGroup = true
            IndicatorID = await Indicators.shared.acquireSharedIndicator(
                groupId: groupId,
                title: "正在加载...",
                icon: .progressIndicator
            )
            
            // 如果提供了 taskName，注册为子任务
            if let taskName = taskName {
                await Indicators.shared.registerSubTask(groupId: groupId, taskName: taskName)
            }
        } else {
            // 向后兼容：使用原有的独立 Indicator 逻辑
            useTaskGroup = false
            IndicatorID = UUID().uuidString
            Toast.progress(id: IndicatorID, title: "正在加载...")
        }
        
        defer {
            if !useTaskGroup {
                Task {
                    await Indicators.shared.dismiss(with: IndicatorID, after: 2)
                }
            }
        }
        
        var count = 0
        do{
            try await flag.withValue(true) {
                do {
                    try Task.checkCancellation()
                    try await ensureToken()
                    let ids = try await getValidIDs()
                    try Task.checkCancellation()
                    guard !ids.isEmpty else {
                        if useTaskGroup, let groupId = groupId, let taskName = taskName {
                            await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                        } else {
                            await Indicators.shared.updateTitle(for: IndicatorID, title: "没有新纪录")
                            await Indicators.shared.updateIcon(for: IndicatorID, icon: .success)
                        }
                        lastRefreshTime = Int(Date().timeIntervalSince1970)
                        return
                    }
                    
                    // 如果使用任务组，不更新标题（由任务组统一管理）
                    if !useTaskGroup {
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "加载\(ids.count)项新纪录")
                    }
                    
                    let saved = try await fetchAndStoreDetails(ids)
                    count = saved
                    lastRefreshTime = Int(Date().timeIntervalSince1970)
                    
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        // 完成子任务，任务组会自动更新标题
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                    } else {
                        // 非任务组模式，更新标题和图标并 dismiss
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "加载了\(saved)个新纪录")
                        await Indicators.shared.updateIcon(for: IndicatorID, icon: .success)
                        await Indicators.shared.dismiss(with: IndicatorID, after: 1)
                    }
                    return
                } catch is CancellationError{
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                    } else {
                        await Indicators.shared.dismiss(with: IndicatorID)
                    }
                    return
                } catch SN3Client.Error.invalidGameServiceToken {
                    if AppUserDefaults.shared.useManualGameServiceToken {
                        if useTaskGroup, let groupId = groupId, let taskName = taskName {
                            await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                            await Indicators.shared.updateTitle(for: IndicatorID, title: "手动令牌已过期，请更新令牌")
                            await Indicators.shared.updateIcon(for: IndicatorID, icon: .systemImage("exclamationmark.triangle"))
                        } else {
                            await Indicators.shared.updateTitle(for: IndicatorID, title: "手动令牌已过期，请更新令牌")
                            await Indicators.shared.updateIcon(for: IndicatorID, icon: .systemImage("exclamationmark.triangle"))
                            await Indicators.shared.dismiss(with: IndicatorID, after: 3)
                        }
                        return
                    } else {
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "令牌已过期，重新获取...")
                        try await NSOAccountManager.shared.refreshGameServiceTokenManual(indicatorId: IndicatorID)
                    }
                }catch SN3Client.Error.tooManyRequests{
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "FAPI请求过于频繁，稍后重试...")
                    } else {
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "FAPI请求过于频繁，稍后重试...")
                        await Indicators.shared.dismiss(with: IndicatorID, after: 3)
                    }
                    return
                }catch {
                    logError(error)
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                    } else {
                        await Indicators.shared.dismiss(with: IndicatorID)
                    }
                    return
                }
            }
        }catch{
            logError(error)
        }
        return count
    }
}
