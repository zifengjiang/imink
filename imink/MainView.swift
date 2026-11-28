import SwiftUI

struct MainView: View {
    @AppStorage("mainViewTabSelection")
    var tabSelection: Int = 0

    @AppStorage(DockConfig.storageKey)
    private var useCustomDock: Bool = true

    @StateObject var mainViewModel = MainViewModel.shared
    @ObservedObject private var dockStore = DockVisibilityStore.shared
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion

    var body: some View {
        Group {
            if useCustomDock {
                // 单物体变形底导壳：原生 62pt Liquid Glass UITabBarController + 原地变形筛选卡片
                ExpandingDockHost(tabSelection: $tabSelection)
                    .ignoresSafeArea()
            } else {
                // 兜底旧路径：完整保留原有 SwiftUI TabView 与滚动收缩、导航标题菜单行为
                tabViewCore
                    .tabBarMinimizeBehavior(.onScrollDown)
            }
        }
        .ignoresSafeArea(.keyboard)
        .appGameTypography()
        // 游戏字体（尤其中文 DFPZongYiW7 只有 1.0× 行高）比 SF Pro 更紧，页面根统一把多行文本行高补到 15pt × 1.2
        .appLineHeight()
        .onChange(of: tabSelection) { _, newValue in
            Haptics.generateIfEnabled(.selectionChanged)
            withAnimation(DockMotion.closeAnimation(reduceMotion: envReduceMotion)) {
                dockStore.collapse()
            }
            // remove all coopDetailViewModelDetail in case of memory leak
            if newValue != 2 {
                AppState.shared.viewModelDict.removeAll()
            }
        }
        .onChange(of: useCustomDock) { _, enabled in
            if !enabled {
                dockStore.collapse()
            }
        }
        .task {
            MainViewModel.shared.isLogin = AppUserDefaults.shared.sessionToken != nil
            await SN3Client.shared.fetchCoops()
            await SN3Client.shared.fetchBattles()
        }
    }

    private var tabViewCore: some View {
        TabView(selection: $tabSelection) {
            HomePage(viewModel: HomeViewModel())
                .toolbar(.visible, for: .tabBar)
                .tabItem {
                    Label("tab_home", image: "TabBarHome")
                }
                .tag(0)

            BattleListView()
                .environmentObject(mainViewModel)
                .toolbar(.visible, for: .tabBar)
                .tabItem {
                    Label("tab_battle", image: "TabBarBattle")
                }
                .tag(1)

            CoopListView()
                .environmentObject(mainViewModel)
                .toolbar(.visible, for: .tabBar)
                .tabItem {
                    Label("tab_salmon_run", image: "TabBarSalmonRun")
                }
                .tag(2)

            MePage()
                .environmentObject(mainViewModel)
                .toolbar(.visible, for: .tabBar)
                .tabItem {
                    Label("tab_me", image: "TabBarMe")
                }
                .tag(3)
        }
    }
}
