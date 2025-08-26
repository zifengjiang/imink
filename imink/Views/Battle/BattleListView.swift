import SwiftUI


struct BattleListView: View {
    @EnvironmentObject var viewModel: BattleListViewModel
    @Environment(\.scenePhase) var scenePhase
    @State var activeID:String?
    @State var showFilterSheet = false
    @State var isSelectionMode = false
    @State var selectedBattles: Set<Int64> = []
    var body: some View {
        NavigationStack{
            ScrollViewReader{ proxy in
                VStack {
                    // 批量操作视图
                    BattleBatchOperationView(
                        selectedBattles: $selectedBattles,
                        isSelectionMode: $isSelectionMode,
                        battles: viewModel.rows.compactMap { $0.battle }
                    )
                    
                    ScrollView{
                        LazyVStack{
                            ForEach(viewModel.rows,id: \.id){row in
                                if row.isBattle {
                                    if !isSelectionMode, let battle = row.battle {
                                        NavigationLink{
                                            BattleDetailView(id: battle.id)
                                        } label: {
                                            BattleListRowView(row: row)
                                            .id(row.id)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    } else {
                                        // 选择模式下的直接显示
                                        BattleListRowView(
                                            row: row,
                                            isSelected: Binding(
                                                get: { selectedBattles.contains(row.battle?.id ?? -1) },
                                                set: { isSelected in
                                                    if let battleId = row.battle?.id {
                                                        if isSelected {
                                                            selectedBattles.insert(battleId)
                                                        } else {
                                                            selectedBattles.remove(battleId)
                                                        }
                                                    }
                                                }
                                            ),
                                            isSelectionMode: isSelectionMode
                                        )
                                        .id(row.id)
                                    }
                                } else {
                                    // 非battle行（如统计卡片）直接显示，不参与选择
                                    BattleListRowView(row: row)
                                        .id(row.id)
                                }
                            }
                    }
                    .scrollTargetLayout()
                }
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
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if !isSelectionMode {
                            Button("选择") {
                                isSelectionMode = true
                            }
                        } else {
                            EmptyView()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showFilterSheet = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .sheet(isPresented: $showFilterSheet) {
                    BattleFilterView(showFilterView: $showFilterSheet, filter: $viewModel.filter) {
                        await viewModel.loadBattles()
                    }
                }
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
//                .onDisappear {
//                    TaskManager.shared.cancel(name: String(describing: Self.self))
//                }
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
