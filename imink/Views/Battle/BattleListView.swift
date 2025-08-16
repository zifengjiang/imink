import SwiftUI


struct BattleListView: View {
    @EnvironmentObject var viewModel: BattleListViewModel
    @Environment(\.scenePhase) var scenePhase
    @State var activeID:String?
    var body: some View {
        NavigationStack{
            ScrollViewReader{ proxy in
                ScrollView{
                    LazyVStack{
                        ForEach(viewModel.rows,id: \.id){row in
                            if row.isBattle, let battle = row.battle {
                                NavigationLink{
                                    BattleDetailView(id: battle.id)
                                } label: {
                                    BattleListRowView(row: row)
                                        .id(row.id)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                BattleListRowView(row: row)
                                    .id(row.id)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .refreshable {
                    TaskManager.shared.start(named: String(describing: Self.self)) {
                        await viewModel.fetchBattles()
                    }
                }
                .scrollPosition(id: $activeID, anchor: .bottom)
                .fixSafeareaBackground()
                .modifier(LoginViewModifier(isLogin: AppState.shared.isLogin, iconName: "TabBarBattle"))
                .navigationTitle(viewModel.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: activeID) { oldValue, newValue in
                    if newValue == viewModel.rows.last?.id {
                        Task{
                            await viewModel.loadMore()
                        }
                    }
                }
                .toolbarTitleMenu {
                    ForEach(BattleMode.allCases,id: \.rawValue){ mode in
                        Button{
                            viewModel.filter.modes.removeAll()
                            if mode != .all {
                                viewModel.filter.modes.insert(mode.rawValue)
                            }
                            viewModel.navigationTitle = mode.name
                            Task{
                                await viewModel.loadBattles()
                            }
                        } label: {
                            Label(
                                title: { Text("\(mode.name)") },
                                icon: { mode.icon }
                            )
                        }
                    }
                }
                .onChange(of: scenePhase) { oldValue, newPhase in
                    switch newPhase {
                    case .active:
                        TaskManager.shared.start(named: String(describing: Self.self)) {
                            await viewModel.fetchBattles()
                        }
                    default:
                        break
                    }
                }
                .onAppear {
                    TaskManager.shared.startLoop(name: String(describing: Self.self), interval: .seconds(300)) {
                        await viewModel.fetchBattles()
                    }
                }
                .onDisappear {
                    TaskManager.shared.cancel(name: String(describing: Self.self))
                }
            }
        }
    }

    struct DetailTabView:View {
        @Binding var selectedRow: String
        @Binding var rows:[BattleListRowInfo]
        var body: some View {

            TabView(selection: $selectedRow) {
                ForEach(rows, id:\.id){ row in
//                    CoopListDetailView(isCoop: row.isCoop, coopId: row.coop?.id, shiftId: row.card?.groupId)
//                        .tag(row.id)
                    Rectangle()
                        .fill(Color.red)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.vertical)
            .fixSafeareaBackground()
        }
    }
}

//#Preview {
//    BattleListView()
//}
