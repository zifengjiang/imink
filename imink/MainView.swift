import SwiftUI
import os

struct MainView: View {
    @AppStorage("mainViewTabSelection")
    var tabSelection: Int = 0

    @AppStorage(DockConfig.storageKey)
    private var useCustomDock: Bool = true

    @StateObject var mainViewModel = MainViewModel.shared
    @ObservedObject private var dockStore = DockVisibilityStore.shared
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var backgroundBlurRadius: CGFloat {
        guard useCustomDock, dockStore.isExpanded, !reduceTransparency else { return 0 }
        return 10 * max(0, 1 - dockStore.dragDismissProgress)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if useCustomDock {
                tabViewCore
                    .tabBarMinimizeBehavior(.never)
                    .blur(radius: backgroundBlurRadius)
                    .animation(DockMotion.panelAnimation(reduceMotion: envReduceMotion), value: dockStore.isExpanded)
                    .accessibilityHidden(dockStore.isExpanded)

                ExpandingDockHost(tabSelection: $tabSelection)
                    .ignoresSafeArea()
                    .zIndex(10)
            } else {
                // 兜底旧路径：完整保留原有系统浮动胶囊 TabView 与滚动收缩行为
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
            withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
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
                .toolbar(useCustomDock ? .hidden : .visible, for: .tabBar)
                .tabItem {
                    Label("tab_home", image: "TabBarHome")
                }
                .tag(0)

            BattleListView()
                .environmentObject(mainViewModel)
                .toolbar(useCustomDock ? .hidden : .visible, for: .tabBar)
                .tabItem {
                    Label("tab_battle", image: "TabBarBattle")
                }
                .tag(1)

            CoopListView()
                .environmentObject(mainViewModel)
                .toolbar(useCustomDock ? .hidden : .visible, for: .tabBar)
                .tabItem {
                    Label("tab_salmon_run", image: "TabBarSalmonRun")
                }
                .tag(2)

            MePage()
                .environmentObject(mainViewModel)
                .toolbar(useCustomDock ? .hidden : .visible, for: .tabBar)
                .tabItem {
                    Label("tab_me", image: "TabBarMe")
                }
                .tag(3)
        }
    }
}
