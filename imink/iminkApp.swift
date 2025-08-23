import SwiftUI
import Combine
import SplatDatabase


@main
struct iminkApp: App {
    @StateObject var coopListViewModel = CoopListViewModel.shared
    @StateObject var battleListViewModel = BattleListViewModel()
    @StateObject var backgroundTaskManager = BackgroundTaskManager.shared
    @StateObject var notificationManager = NotificationManager.shared

    init(){
        #if DEBUG
        print(SplatDatabase.shared.dbQueue.path)
        #endif
        
        // 注册后台任务
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
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
                    .environmentObject(backgroundTaskManager)
                    .environmentObject(notificationManager)
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
                
                // 请求通知权限并启动后台刷新
                Task {
                    await NotificationManager.shared.requestNotificationPermission()
                    BackgroundTaskManager.shared.scheduleBackgroundRefresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                BackgroundTaskManager.shared.handleAppWillResignActive()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                BackgroundTaskManager.shared.handleAppDidBecomeActive()
                // 当用户返回应用时，标记数据为已查看
                BackgroundTaskManager.shared.markDataAsViewed()
                NotificationManager.shared.clearDataUpdateNotifications()
            }
            
        }
    }
}
