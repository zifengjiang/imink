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

    // MARK: - Sync 结果日志
/// 记录「请求多少 / 真正落库多少」，让 `log stream` 里一眼能看出写入是否成功。
@inline(__always)
func logSyncResult(kind: String, requested: Int, saved: Int) {
    os_log(
        "sync[%{public}@] requested=%d saved=%d",
        type: saved == requested ? .info : .error,
        kind, requested, saved
    )
}

/// 把同步失败翻译成用户能看懂的一句话（不会把技术细节藏进日志）。
func syncFailureMessage(_ error: any Error) -> String {
    let nsError = error as NSError
    if nsError.domain == "SQLite" || nsError.domain.contains("GRDB") || nsError.domain == "SQLite.Result" {
        return "写入数据库失败：\(error.localizedDescription)"
    }
        // 限流要告诉用户「到底要等多久」，而不是笼统的「稍后重试」；
        // 诊断用的长链（哪家提供方、原始响应）留在 lastSyncDebug 里，不塞进 toast。
    if let error = error as? NSOAuthorization.NSOAuthError, case let .rateLimited(until, provider, _) = error {
        let remaining = max(0, (until - Int(Date().timeIntervalSince1970 * 1000) + 999) / 1000)
        return "生成 f 值被限流（\(provider)），请在 \(FAPICooldown.durationText(remaining))后重试（\(FAPICooldown.clockText(until)) 之后）"
    }
    if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
        return "同步失败：\(localized)"
    }
    return "同步失败：\(error.localizedDescription)"
}


    // MARK: - SN3Client token helper
extension SN3Client {
    func ensureToken() async throws {
        // 以前这里把 refreshGameServiceTokenIfNeeded() 注释掉了：一旦 app group 里没有
        // `gameServiceToken`（重装/重登后很常见），后面所有 splatnet3 请求都会不带
        // Authorization 发出去，服务端回「HTTP 400 + 空 body」，UI 上就是“加载完成但没有记录”。
        let token = try await NSOAccountManager.shared.ensureGameServiceToken()
        try await setToken(token)
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
        var failed = false
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
                        // 整体拉取成功（只是没新数据）→ 清掉上次的错误，避免误导
                        AppUserDefaults.shared.lastSyncError = nil
                        AppUserDefaults.shared.lastSyncDebug = nil
                        return
                    }
                    
                    // 如果使用任务组，不更新标题（由任务组统一管理）
                    if !useTaskGroup {
                        await Indicators.shared.updateTitle(for: IndicatorID, title: "加载\(ids.count)项新纪录")
                    }
                    
                    let saved = try await fetchAndStoreDetails(ids)
                    count = saved
                    lastRefreshTime = Int(Date().timeIntervalSince1970)

                    // 落库行数才是结果：抓到的 id 数 > 实际写入数 = 部分或全部写入失败
                    let isPartial = saved < ids.count
                    AppUserDefaults.shared.lastSyncError = isPartial ? "仅写入 \(saved)/\(ids.count) 条记录" : nil
                    if !isPartial { AppUserDefaults.shared.lastSyncDebug = nil }
                    logSyncResult(kind: taskName ?? "records", requested: ids.count, saved: saved)

                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        // 完成子任务，任务组会自动更新标题
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                        if isPartial {
                            await Indicators.shared.updateTitle(for: IndicatorID, title: "仅写入 \(saved)/\(ids.count) 条")
                        }
                    } else {
                        // 非任务组模式，更新标题和图标并 dismiss
                        if isPartial {
                            await Indicators.shared.updateTitle(for: IndicatorID, title: "仅写入 \(saved)/\(ids.count) 条记录")
                            await Indicators.shared.updateIcon(for: IndicatorID, icon: .systemImage("exclamationmark.triangle"))
                            await Indicators.shared.dismiss(with: IndicatorID, after: 3)
                        } else {
                            await Indicators.shared.updateTitle(for: IndicatorID, title: "加载了\(saved)个新纪录")
                            await Indicators.shared.updateIcon(for: IndicatorID, icon: .success)
                            await Indicators.shared.dismiss(with: IndicatorID, after: 1)
                        }
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
                        // 令牌刷新了，但本次抓取并未重试：必须让调用方知道这一轮没有数据，
                        // 否则后台任务会把它当成「没有新纪录」而定下一个 15 分钟的沉默。
                        failed = true
                        AppUserDefaults.shared.lastSyncError = "游戏服务令牌已刷新，请再次刷新数据"
                        return
                    }
                }catch SN3Client.Error.tooManyRequests{
                    failed = true
                    let message = FAPICooldown.message(prefix: "FAPI 请求被限流")
                    AppUserDefaults.shared.lastSyncError = message
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                        await Indicators.shared.updateTitle(for: IndicatorID, title: message)
                        await Indicators.shared.updateIcon(for: IndicatorID, icon: .systemImage("exclamationmark.triangle"))
                    } else {
                        await Indicators.shared.updateTitle(for: IndicatorID, title: message)
                        await Indicators.shared.updateIcon(for: IndicatorID, icon: .systemImage("exclamationmark.triangle"))
                        await Indicators.shared.dismiss(with: IndicatorID, after: 4)
                    }
                    Toast.failure(message)
                    return
                }catch {
                    logError(error)
                    failed = true
                    // 落库/拉取失败必须对用户可见，而不是只把进度条收掉
                    let message = syncFailureMessage(error)
                    AppUserDefaults.shared.lastSyncError = message
                    // 不是 HTTP 层错误（例如落库失败、解析失败）时，SN3Client 那边没有快照，
                    // 这里补一条，保证 prefs 里总能看到「为什么失败」
                    if SyncDiagnostics.last == nil {
                        SyncDiagnostics.noteFailure(
                            api: "local",
                            query: taskName,
                            webVersion: SN3Client.shared.webVersion,
                            webVersionSource: SN3Client.shared.webVersionSourceLabel,
                            status: nil,
                            responseBody: nil,
                            error: message
                        )
                    }
                    if useTaskGroup, let groupId = groupId, let taskName = taskName {
                        await Indicators.shared.completeSubTask(groupId: groupId, taskName: taskName)
                        await Indicators.shared.updateTitle(for: IndicatorID, title: message)
                        await Indicators.shared.updateIcon(for: IndicatorID, icon: .systemImage("exclamationmark.triangle"))
                    } else {
                        await Indicators.shared.updateTitle(for: IndicatorID, title: message)
                        await Indicators.shared.updateIcon(for: IndicatorID, icon: .systemImage("exclamationmark.triangle"))
                        await Indicators.shared.dismiss(with: IndicatorID, after: 4)
                    }
                    Toast.failure(message)
                    return
                }
            }
        }catch{
            logError(error)
            failed = true
        }
        return failed ? nil : count
    }
}
// MARK: - My Gear Collection

extension SN3Client {
    @MainActor
    func fetchMyGearCollection(language: String) async throws -> MyGearCollection {
        await refreshWebConfigurationIfAvailable()

        let webSession: SplatNetWebSession
        do {
            webSession = try await SplatNetWebSessionProvider.load()
        } catch let error as DecodingError {
            logError(error, "无法解析 Nintendo 账户响应")
            throw MyGearCollectionError.invalidAccountResponse
        }

        let cacheKey = MyGearCollectionRequestCache.Key(
            session: webSession,
            interfaceLanguage: language
        )
        return try await MyGearCollectionRequestCache.shared.value(
            for: cacheKey
        ) { [self] in
            try await fetchMyGearCollectionUncached(
                language: language,
                webSession: webSession
            )
        }
    }

    @MainActor
    private func fetchMyGearCollectionUncached(
        language: String,
        webSession: SplatNetWebSession
    ) async throws -> MyGearCollection {

        do {
            try await setToken(
                webSession.gameWebToken,
                country: webSession.country,
                accountLanguage: webSession.accountLanguage,
                interfaceLanguage: language
            )
        } catch let error as DecodingError {
            logError(error, "无法解析鱿鱼圈登录响应")
            throw MyGearCollectionError.invalidBulletTokenResponse
        }

        let responseData: Data
        do {
            responseData = try await graphQL(
                .myOutfitCommonDataEquipments(
                    language: language,
                    gameWebToken: webSession.gameWebToken,
                    country: webSession.country,
                    accountLanguage: webSession.accountLanguage
                )
            )
        } catch let error as DecodingError {
            logError(error, "刷新鱿鱼圈登录响应失败")
            throw MyGearCollectionError.invalidBulletTokenResponse
        }

        do {
            return try MyGearResponseDecoder.decode(responseData)
        } catch {
            logError(error, "无法解析装备响应")
            throw error
        }
    }
}
