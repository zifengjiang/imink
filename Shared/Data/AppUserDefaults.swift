import Foundation
import SwiftUI

class AppUserDefaults: ObservableObject {
    static let shared = AppUserDefaults()

    @AppStorage("firstLaunch", store: .appGroup)
    var firstLaunch: Bool = true {
        didSet {

        }
    }

    @AppStorage("NSOVersion", store: .appGroup)
    var NSOVersion: String = "2.10.1"

    @AppStorage("currentLanguage", store: .appGroup)
    var currentLanguage: String?

    @AppStorage("session_token", store: .appGroup)
    var sessionToken: String? {
        didSet {
            AppState.shared.isLogin = sessionToken != nil
            if sessionToken != oldValue {
                nintendoAccountCountry = nil
                nintendoAccountLanguage = nil
            }
        }
    }

    @AppStorage("nintendoAccountCountry", store: .appGroup)
    var nintendoAccountCountry: String?

    @AppStorage("nintendoAccountLanguage", store: .appGroup)
    var nintendoAccountLanguage: String?

    @AppStorage("coopSummary", store: .appGroup)
    var coopSummary: String?

    @AppStorage("history_record", store: .appGroup)
    var historyRecord: String?

    @AppStorage("accountId", store: .appGroup)
    var accountId: Int = 1

    @AppStorage("gameServiceToken", store: .appGroup)
    var gameServiceToken: String?

    @AppStorage("gameServiceTokenRefreshTime", store: .appGroup)
    var gameServiceTokenRefreshTime: Int = 0

    @AppStorage("coopsRefreshTime", store: .appGroup)
    var coopsRefreshTime: Int = 0

    @AppStorage("battlesRefreshTime", store: .appGroup)
    var battlesRefreshTime: Int = 0

    /// 最近一次同步失败原因（成功时置 nil）。
    ///
    /// 以前同步失败只进 os_log，UI 上只有一句「加载完成」，用户完全看不见。
    /// 现在失败原因存在这里，开发者设置页会展示，便于现场定位。
    @AppStorage("lastSyncError", store: .appGroup)
    var lastSyncError: String?

    @AppStorage("scheduleRefreshTime", store: .appGroup)
    var scheduleRefreshTime: Int = 0
    
    @AppStorage("fapiLastRequestTime", store: .appGroup)
    var fapiLastRequestTime: Int = 0
    
    @AppStorage("fapiRequestInterval", store: .appGroup)
    var fapiRequestInterval: Int = 1800000 // 默认30分钟间隔（30 * 60 * 1000毫秒）
    
    @AppStorage("manualGameServiceToken", store: .appGroup)
    var manualGameServiceToken: String?
    
    @AppStorage("useManualGameServiceToken", store: .appGroup)
    var useManualGameServiceToken: Bool = false
    
    // MARK: - 记录缓存相关
    @AppStorage("stageRecordsCache", store: .appGroup)
    private var stageRecordsCacheData: Data = Data()
    
    @AppStorage("weaponRecordsCache", store: .appGroup)
    private var weaponRecordsCacheData: Data = Data()
    
    @AppStorage("coopRecordCache", store: .appGroup)
    private var coopRecordCacheData: Data = Data()
    
    // 场地记录缓存
    var stageRecordsCache: [StageRecord] {
        get {
            guard !stageRecordsCacheData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([StageRecord].self, from: stageRecordsCacheData)
            } catch {
                print("解码场地记录缓存失败: \(error)")
                return []
            }
        }
        set {
            do {
                stageRecordsCacheData = try JSONEncoder().encode(newValue)
                objectWillChange.send()
            } catch {
                print("编码场地记录缓存失败: \(error)")
            }
        }
    }
    
    // 武器记录缓存
    var weaponRecordsCache: WeaponRecords? {
        get {
            guard !weaponRecordsCacheData.isEmpty else { return nil }
            do {
                return try JSONDecoder().decode(WeaponRecords.self, from: weaponRecordsCacheData)
            } catch {
                print("解码武器记录缓存失败: \(error)")
                return nil
            }
        }
        set {
            do {
                weaponRecordsCacheData = try JSONEncoder().encode(newValue)
                objectWillChange.send()
            } catch {
                print("编码武器记录缓存失败: \(error)")
            }
        }
    }
    
    // 合作模式记录缓存
    var coopRecordCache: CoopRecord? {
        get {
            guard !coopRecordCacheData.isEmpty else { return nil }
            do {
                return try JSONDecoder().decode(CoopRecord.self, from: coopRecordCacheData)
            } catch {
                print("解码合作模式记录缓存失败: \(error)")
                return nil
            }
        }
        set {
            do {
                coopRecordCacheData = try JSONEncoder().encode(newValue)
                objectWillChange.send()
            } catch {
                print("编码合作模式记录缓存失败: \(error)")
            }
        }
    }
    
    // MARK: - 铭牌编辑器设置
    @AppStorage("nameplateSettings", store: .appGroup)
    private var nameplateSettingsData: Data = Data()
    
    // 铭牌编辑器设置
    var nameplateSettings: NameplateSettings {
        get {
            guard !nameplateSettingsData.isEmpty else { return .defaultSettings }
            do {
                return try JSONDecoder().decode(NameplateSettings.self, from: nameplateSettingsData)
            } catch {
                print("解码铭牌设置失败: \(error)")
                return .defaultSettings
            }
        }
        set {
            do {
                nameplateSettingsData = try JSONEncoder().encode(newValue)
                objectWillChange.send()
            } catch {
                print("编码铭牌设置失败: \(error)")
            }
        }
    }
    
    // MARK: - 日程订阅相关
    @AppStorage("scheduleSubscriptions", store: .appGroup)
    private var subscriptionsData: Data = Data()
    
    @AppStorage("notificationSettings", store: .appGroup)
    private var notificationSettingsData: Data = Data()
    
    // 订阅列表
    var scheduleSubscriptions: [ScheduleSubscription] {
        get {
            guard !subscriptionsData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([ScheduleSubscription].self, from: subscriptionsData)
            } catch {
                logError("解码订阅数据失败: \(error)" as! Error)
                return []
            }
        }
        set {
            do {
                subscriptionsData = try JSONEncoder().encode(newValue)
                objectWillChange.send()
            } catch {
                logError("编码订阅数据失败: \(error)" as! Error)
            }
        }
    }
    
    // 通知设置
    var notificationSettings: NotificationSettings {
        get {
            guard !notificationSettingsData.isEmpty else { return .default }
            do {
                return try JSONDecoder().decode(NotificationSettings.self, from: notificationSettingsData)
            } catch {
                logError("解码通知设置失败: \(error)" as! Error)
                return .default
            }
        }
        set {
            do {
                notificationSettingsData = try JSONEncoder().encode(newValue)
                objectWillChange.send()
            } catch {
                logError("编码通知设置失败: \(error)" as! Error)
            }
        }
    }
}


extension UserDefaults {
    /// App Group 共享容器：主 App 与 Live Activity / Widget 扩展共用。
    /// 注意：只有两个 target 都签了 `com.apple.security.application-groups` entitlement，
    /// `UserDefaults(suiteName:)` 才会返回容器；缺失时它会返回 nil，
    /// 这里降级到 `.standard` 并记录日志，避免启动即崩溃（不丢数据的 key 会回落到本 App 沙盒）。
    static let appGroup: UserDefaults = {
        let suiteName = "group.jiang.feng.imink"
        if let shared = UserDefaults(suiteName: suiteName) {
            return shared
        }
        let error = NSError(
            domain: "imink.AppGroup",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "无法打开 App Group 容器 \(suiteName)，已降级到 .standard；请检查 application-groups entitlement"
            ]
        )
        logError(error)
        return .standard
    }()
}
