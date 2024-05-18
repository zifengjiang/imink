import Foundation

class MainViewModel: ObservableObject {

    @Published var isLogin: Bool = false

    init() {
            // Check language and refresh widget
        let currentLanguage = AppUserDefaults.shared.currentLanguage
        if let code = Bundle.main.preferredLocalizations.last {
            if code != currentLanguage {
                AppUserDefaults.shared.currentLanguage = code
            }
        }
    }
}
