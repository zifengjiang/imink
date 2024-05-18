import SwiftUI

struct ContentView: View {
    @AppStorage("mainViewTabSelection")
    var tabSelection:Int = 0
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


            Text("主页")
                .tabItem {
                    Label("tab_salmon_run", image: "TabBarSalmonRun")
                }
                .tag(2)


            MePage()
                .tabItem {
                    Label("tab_me", image: "TabBarMe")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
