import Foundation
import SplatDatabase
import Combine
import SplatNet3API
import SwiftyJSON


class MainViewModel: ObservableObject {
    static let shared = MainViewModel()

    @Published var isLogin: Bool = NSOAccountManager.shared.isLogin

    private var cancelBag = Set<AnyCancellable>()
    init() {
        let currentLanguage = AppUserDefaults.shared.currentLanguage
        if let code = Bundle.main.preferredLocalizations.last {
            if code != currentLanguage {
                AppUserDefaults.shared.currentLanguage = code
            }
        }

        NSOAccountManager.shared.$isLogin
            .assign(to: \.isLogin, on: self)
            .store(in: &cancelBag)

    }

   
}

