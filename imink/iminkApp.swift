import SwiftUI
import SplatDatabase

@main
struct iminkApp: App {
    @StateObject var coopListViewModel = CoopListViewModel.shared
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(coopListViewModel)
        }
    }
}
