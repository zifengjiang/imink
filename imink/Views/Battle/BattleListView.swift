import SwiftUI


struct BattleListView: View {
    @EnvironmentObject var viewModel: BattleListViewModel
    @State var activeID:String?
    var body: some View {
        NavigationStack{
            ScrollViewReader{ proxy in
                ScrollView{
                    LazyVStack{
                        ForEach(viewModel.rows,id: \.id){row in
                            NavigationLink{
                                BattleDetailView(id: row.battle!.id)
                            } label: {
                                BattleListRowView(detail: row.battle!)
                                    .id(row.id)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .refreshable {
                    viewModel.fetchBattles()
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
