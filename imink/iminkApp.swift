import SwiftUI
import SplatDatabase
import IndicatorsKit

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
            ZStack{
                MainView()
                    .environmentObject(coopListViewModel)
            }
            .overlay(alignment: .top) {
                IndicatorsOverlay(model: Indicators.shared)
            }
        }
    }
}
