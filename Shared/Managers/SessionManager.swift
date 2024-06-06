import Foundation
import Combine

class SessionManager {
    static let shared = SessionManager()

    private var isValidSubject: CurrentValueSubject<Bool, Never>

    private static var isValid: Bool {
        if let _ = AppUserDefaults.shared.gameServiceToken {
                return Date().timeIntervalSince1970 - Double(AppUserDefaults.shared.gameServiceTokenRefreshTime) < 10800
        }
        return false
    }
    
    var cancelBag: Set<AnyCancellable>

    init() {
        cancelBag = Set<AnyCancellable>()

        isValidSubject = CurrentValueSubject<Bool, Never>(SessionManager.isValid)
    }
}
