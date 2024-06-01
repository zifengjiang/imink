import SwiftUI
import SplatDatabase

@main
struct iminkApp: App {
    @StateObject var coopListViewModel = CoopListViewModel.shared

    init(){
        #if DEBUG
        print(SplatDatabase.shared.dbQueue.path)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(coopListViewModel)
        }
    }
}
