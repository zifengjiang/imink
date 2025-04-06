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
        }
    }

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
}


extension UserDefaults {
    static let appGroup: UserDefaults = {
        return UserDefaults(suiteName: "group.jiang.feng.imink")!
    }()
}
