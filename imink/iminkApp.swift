import SwiftUI
import Combine
import SplatDatabase


@main
struct iminkApp: App {
    @StateObject var coopListViewModel = CoopListViewModel.shared
    @StateObject var battleListViewModel = BattleListViewModel()

    init(){
        #if DEBUG
        print(SplatDatabase.shared.dbQueue.path)
        #endif
        // Fix the problem that NavgationView and TabBar has no background when Stack style.
        if #available(iOS 15.0, *) {
            let navigationBarAppearance = UINavigationBarAppearance()
            let defaultAppearance = UINavigationBar.appearance()
            defaultAppearance.standardAppearance = navigationBarAppearance
            defaultAppearance.scrollEdgeAppearance = navigationBarAppearance

            let tabBarAppearance = UITabBarAppearance()
            let appAppearance = UITabBar.appearance()
            appAppearance.standardAppearance = tabBarAppearance
            appAppearance.scrollEdgeAppearance = tabBarAppearance
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
                    if let version = version{
                        AppUserDefaults.shared.NSOVersion = version
                    }
                }
            }
            
        }
    }
}
