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
    var NSOVersion: String = "2.10.0"

    @AppStorage("currentLanguage", store: .appGroup)
    var currentLanguage: String?

    @AppStorage("session_token", store: .appGroup)
    var sessionToken: String? {
        didSet {
            MainViewModel.shared.isLogin = sessionToken != nil
        }
    }

    @AppStorage("accountId", store: .appGroup)
    var accountId: Int = 1

    @AppStorage("gameServiceToken", store: .appGroup)
    var gameServiceToken: String?

    @AppStorage("gameServiceTokenRefreshTime", store: .appGroup)
    var gameServiceTokenRefreshTime: Int = 0
}


extension UserDefaults {
    static let appGroup: UserDefaults = {
        return UserDefaults(suiteName: "group.jiang.feng.imink")!
    }()
}
