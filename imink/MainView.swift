import SwiftUI
import os

struct MainView: View {
    @AppStorage("mainViewTabSelection")
    var tabSelection:Int = 0

    @StateObject var mainViewModel = MainViewModel.shared
    var body: some View {
        TabView(selection:$tabSelection){
            HomePage(viewModel: HomeViewModel())
                .tabItem {
                    Label("tab_home", image: "TabBarHome")
                }
                .tag(0)

            Text("主页")
                .tabItem {
                    Label("tab_battle", image: "TabBarBattle")
                }
                .tag(1)


            CoopListPage()
                .environmentObject(mainViewModel)
                .tabItem {
                    Label("tab_salmon_run", image: "TabBarSalmonRun")
                }
                .tag(2)


            MePage()
                .environmentObject(mainViewModel)
                .tabItem {
                    Label("tab_me", image: "TabBarMe")
                }
                .tag(3)
        }
        .task {
            MainViewModel.shared.isLogin = AppUserDefaults.shared.sessionToken != nil
            do{
                try await MainViewModel.shared.loadCoop()
            }catch{
                os_log("Error: [loadCoop] \(error.localizedDescription)")
            }

        }
    }
}

#Preview {
    MainView()
}
