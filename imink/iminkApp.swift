import SwiftUI
import Combine
import SplatDatabase
import IndicatorsKit

@main
struct iminkApp: App {
    @StateObject var coopListViewModel = CoopListViewModel.shared
    @StateObject var battleListViewModel = BattleListViewModel()
    @Environment(\.scenePhase) var scenePhase

    init(){
        #if DEBUG
        print(SplatDatabase.shared.dbQueue.path)
        #endif
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = UITabBar.appearance().standardAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBar.appearance().standardAppearance
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack{
                MainView()
                    .environmentObject(coopListViewModel)
                    .environmentObject(battleListViewModel)
            }
            .overlay(alignment: .top) {
                IndicatorsOverlay(model: Indicators.shared)
            }
            .onAppear{
                getNsoVersion { version in
                    if let _ = version{
                        AppUserDefaults.shared.NSOVersion = "2.10.1"
                    }
                }
            }
            .onChange(of: scenePhase) { oldValue, newPhase in
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
