import SwiftUI

struct BattleListView: View {
    @EnvironmentObject var viewModel: BattleListViewModel
    @Namespace private var animation
    @State var activeID:String?
    @State private var selection = RecordSelection<Int64>()
    @AppStorage(DockConfig.storageKey) private var useCustomDock: Bool = true
    #if DEBUG
    @AppStorage("debugScrollToBottom") private var debugScrollToBottom: Bool = false
    #endif

    private var visibleBattleIds: [Int64] {
        viewModel.rows.compactMap { $0.detail?.id }
    }

    var body: some View {
        NavigationStack{
            ScrollViewReader { proxy in
                VStack {

                    ScrollView{
                        LazyVStack{
                            ForEach(viewModel.rows,id: \.id){row in
                                if let battle = row.detail {
                                    SelectableRowView(
                                        isSelectionMode: selection.isActive,
                                        isSelected: selection.contains(battle.id),
                                        onTap: {
                                            selection.toggle(battle.id)
                                        }
                                    ) {
                                        if !selection.isActive {
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
                                } else {
                                        // 非battle行（如统计卡片）直接显示，不参与选择
                                    if !selection.isActive, let card = row.card {
                                        NavigationLink {
                                            BattleShiftDetailView(groupId: Int(card.groupId))
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
                        }
                        .scrollTargetLayout()
                    }
                    #if DEBUG
                    .defaultScrollAnchor(debugScrollToBottom ? .bottom : nil)
                    .onChange(of: viewModel.rows.count) { _, _ in
                        guard debugScrollToBottom else { return }
                        Task { @MainActor in
                            for delay in [300_000_000 as UInt64, 500_000_000 as UInt64] {
                                try? await Task.sleep(nanoseconds: delay)
                                if let lastId = viewModel.rows.last?.id {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                    }
                    #endif
                }
                .refreshable {
                    TaskManager.shared.start(named: String(describing: Self.self)) {
                        await viewModel.fetchBattles()
                    }
                }
                .scrollPosition(id: $activeID, anchor: .bottom)
                .dockScrollMinimizeObserver()
                .fixSafeareaBackground()
                .modifier(LoginViewModifier(isLogin: AppState.shared.isLogin, iconName: "TabBarBattle"))
                .navigationTitle(viewModel.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    RecordSelectionToolbar(
                        selection: $selection,
                        visibleIds: visibleBattleIds,
                        onFavorite: batchToggleFavorite,
                        onDelete: batchDelete,
                        filterButton: AnyView(
                            Button {
                                viewModel.showFilterSheet = true
                            } label: {
                                Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        )
                    )
                    .matchedTransitionSource(id: "filter", in: animation)
                }
                .sheet(isPresented: $viewModel.showFilterSheet) {
                    BattleFilterView(showFilterView: $viewModel.showFilterSheet, filter: $viewModel.filter) {
                        await viewModel.loadBattles()
                    }
                    .navigationTransition(.zoom(sourceID: "filter", in: animation))
                }
                .onChange(of: activeID) { oldValue, newValue in
                    if newValue == viewModel.rows.last?.id {
                        Task{
                            await viewModel.loadMore()
                        }
                    }
                }
                .modifier(LegacyBattleTitleMenuModifier(isEnabled: !useCustomDock, viewModel: viewModel))
                    //                .onChange(of: scenePhase) { oldValue, newPhase in
                    //                    switch newPhase {
                    //                    case .active:
                    //                        TaskManager.shared.start(named: String(describing: Self.self)) {
                    //                            await viewModel.fetchBattles()
                    //                        }
                    //                    default:
                    //                        break
                    //                    }
                    //                }
                    //                .onAppear {
                    //                    TaskManager.shared.startLoop(name: String(describing: Self.self), interval: .seconds(300)) {
                    //                        await viewModel.fetchBattles()
                    //                    }
                    //                }
                    //                .onDisappear {
                    //                    TaskManager.shared.cancel(name: String(describing: Self.self))
                    //                }
            }
        }
    }

    private func batchToggleFavorite() {
        let selectedBattleIds = Array(selection.selectedIds)

        Task {
            do {
                try await viewModel.toggleFavorites(ids: selectedBattleIds)
                selection.cancel()
            } catch {
                print("Error batch toggling favorites: \(error)")
            }
        }
    }

    private func batchDelete() {
        let selectedBattleIds = Array(selection.selectedIds)

        Task {
            let succeeded = await BatchOperation.run(
                title: "正在删除",
                totalCount: selectedBattleIds.count,
                successTitle: "删除完成",
                successSubtitle: { "已删除 \($0) 条记录" },
                failureTitle: "删除失败"
            ) { reportProgress in
                try await viewModel.softDelete(ids: selectedBattleIds, onProgress: reportProgress)
            }

            if succeeded {
                selection.cancel()
            }
        }
    }
}

    //#Preview {
    //    BattleListView()
    //}

private struct LegacyBattleTitleMenuModifier: ViewModifier {
    let isEnabled: Bool
    @ObservedObject var viewModel: BattleListViewModel

    func body(content: Content) -> some View {
        if isEnabled {
            content.toolbarTitleMenu {
                ForEach(BattleMode.allCases, id: \.rawValue) { mode in
                    Button {
                        Task {
                            await viewModel.selectModeFromDock(mode)
                        }
                    } label: {
                        Label(
                            title: { Text("\(mode.name)") },
                            icon: { mode.icon }
                        )
                    }
                }
            }
        } else {
            content
        }
    }
}
