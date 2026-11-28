import SwiftUI

struct CoopListView: View {
    @EnvironmentObject var viewModel: CoopListViewModel
    @Namespace private var animation
    @State var activeID:String?
    @State var selectedRow:String?
    @State var isFirstRow = true
    @State private var selection = RecordSelection<Int64>()
    @State private var navigationPath = NavigationPath()
    @AppStorage(DockConfig.storageKey) private var useCustomDock: Bool = true
    #if DEBUG
    @AppStorage("debugScrollToBottom") private var debugScrollToBottom: Bool = false
    #endif

    private var visibleCoopIds: [Int64] {
        viewModel.rows.compactMap { $0.detail?.id }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollViewReader { proxy in
                VStack {
                    ScrollView{
                        LazyVStack{
                            ForEach(viewModel.rows, id:\.id){ row in
                                    SelectableRowView(
                                        isSelectionMode: selection.isActive,
                                        isSelected: row.detail.map { selection.contains($0.id) } ?? false,
                                        onTap: {
                                            if let coopId = row.detail?.id {
                                                selection.toggle(coopId)
                                            }
                                        }
                                    ) {
                                        if !selection.isActive {
                                            NavigationLink(value: row.id) {
                                                CoopListRowView(row: row)
                                                    .id(row.id)
                                                    .onAppear {
                                                        checkForLoadMore(rowId: row.id)
                                                    }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        } else {
                                            CoopListRowView(row: row)
                                                .id(row.id)
                                                .onAppear {
                                                    checkForLoadMore(rowId: row.id)
                                                }
                                        }
                                    }

                            }
                            .scrollTargetLayout()
                        }
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
                    .refreshable {
                        TaskManager.shared.start(named: String(describing: Self.self)) {
                            await viewModel.fetchCoops()
                        }
                    }
                    .scrollPosition(id: $activeID, anchor: .bottom)
                    .dockScrollMinimizeObserver()
                    .fixSafeareaBackground()
                    .modifier(LoginViewModifier(isLogin: AppState.shared.isLogin, iconName: "TabBarSalmonRun"))
                    .navigationTitle(viewModel.navigationTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .onChange(of: activeID) { oldValue, newValue in
                        if newValue == viewModel.rows.last?.id {
                            Task{
                                if viewModel.navigationTitle == "打工卡片"{
                                    await viewModel.loadMoreCards()
                                    return
                                }
                                await viewModel.loadMore()
                            }
                        }
                    }
                    .onChange(of: selectedRow, { oldValue, newValue in
                        proxy.scrollTo(newValue,anchor: .center)
                        self.isFirstRow = newValue == viewModel.rows.first?.id
                        viewModel.loadCurrentCoopFavoriteStatus(for: newValue)
                        if newValue == viewModel.rows.last?.id {
                            Task{
                                if viewModel.navigationTitle == "打工卡片"{
                                    await viewModel.loadMoreCards()
                                    return
                                }
                                await viewModel.loadMore()
                            }
                        }
                    })
                    .toolbar {
                        RecordSelectionToolbar(
                            selection: $selection,
                            visibleIds: visibleCoopIds,
                            onFavorite: batchToggleFavorite,
                            onDelete: batchDelete,
                            filterButton: AnyView(
                                Button {
                                    viewModel.showFilterSheet = true
                                } label: {
                                    Label("筛选", systemImage: "line.horizontal.3.decrease.circle")
                                }
                            )
                        )
                        .matchedTransitionSource(id: "filter", in: animation)
                    }
                    .modifier(LegacyCoopTitleMenuModifier(isEnabled: !useCustomDock, viewModel: viewModel))
//                    .onChange(of: scenePhase) { oldValue, newPhase in
//                        switch newPhase {
//                        case .active:
//                            TaskManager.shared.start(named: String(describing: Self.self)) {
//                                await viewModel.fetchCoops()
//                            }
//                        default:
//                            break
//                        }
//                    }
//                    .onAppear {
//                        TaskManager.shared.startLoop(name: String(describing: Self.self), interval: .seconds(300)) {
//                            await viewModel.fetchCoops()
//                        }
//                    }
                }

            }
            .navigationDestination(for: String.self) { rowId in
                CoopDetailPage(
                    rowId: rowId,
                    viewModel: viewModel,
                    navigationPath: $navigationPath
                )
                .environmentObject(viewModel)
                .onAppear {
                    selectedRow = rowId
                }
            }
            .sheet(isPresented: $viewModel.showFilterSheet){
                CoopFilterView(showFilterView: $viewModel.showFilterSheet, filter: $viewModel.filter){
                    guard AppState.shared.isLogin else { return }
                    await viewModel.loadCoops()
                }
                .navigationTransition(.zoom(sourceID: "filter", in: animation))
            }
        }
    }

    
    private func batchToggleFavorite() {
        let selectedCoopIds = Array(selection.selectedIds)

        Task {
            do {
                try await viewModel.toggleFavorites(ids: selectedCoopIds)
                selection.cancel()
            } catch {
                print("Error batch toggling favorites: \(error)")
            }
        }
    }
    
    private func checkForLoadMore(rowId: String) {
        if rowId == viewModel.rows.last?.id {
            Task {
                if viewModel.navigationTitle == "打工卡片" {
                    await viewModel.loadMoreCards()
                    return
                }
                await viewModel.loadMore()
            }
        }
    }
    
    private func batchDelete() {
        let selectedCoopIds = Array(selection.selectedIds)

        Task {
            let succeeded = await BatchOperation.run(
                title: "正在删除",
                totalCount: selectedCoopIds.count,
                successTitle: "删除完成",
                successSubtitle: { "已删除 \($0) 条记录" },
                failureTitle: "删除失败"
            ) { reportProgress in
                try await viewModel.softDelete(ids: selectedCoopIds, onProgress: reportProgress)
            }

            if succeeded {
                selection.cancel()
            }
        }
    }

}


    //#Preview {
    //    CoopListView()
    //}

private struct LegacyCoopTitleMenuModifier: ViewModifier {
    let isEnabled: Bool
    @ObservedObject var viewModel: CoopListViewModel

    func body(content: Content) -> some View {
        if isEnabled {
            content.toolbarTitleMenu {
                ForEach(CoopRule.allCases, id: \.rawValue) { rule in
                    Button {
                        Task {
                            await viewModel.selectRuleFromDock(rule)
                        }
                    } label: {
                        Label(
                            title: { Text("\(rule.name)") },
                            icon: { rule.icon }
                        )
                    }
                }

                Button {
                    Task {
                        await viewModel.selectShiftCardsFromDock()
                    }
                } label: {
                    Label(
                        title: { Text("打工卡片") },
                        icon: { Image(systemName: "creditcard") }
                    )
                }
            }
        } else {
            content
        }
    }
}
