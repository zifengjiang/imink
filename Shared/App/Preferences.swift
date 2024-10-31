
import Foundation
import SwiftUI

public final class Preferences: ObservableObject, @unchecked Sendable {
    public static let shared = Preferences()

    @AppStorage("EnableHaptics", store: .appGroup)
    public var enableHaptics = true
}
