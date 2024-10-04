import SwiftUI
import SplatDatabase
import IndicatorsKit

@main
struct iminkApp: App {
    @StateObject var coopListViewModel = CoopListViewModel.shared
    @Environment(\.scenePhase) var scenePhase

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
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    Task{
                        await coopListViewModel.fetchCoops()
                    }
                default:
                    break
                }
            }
        }
    }
}
