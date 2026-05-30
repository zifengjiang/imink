import SwiftUI
import SplatDatabase
import GRDB


struct BattleListView: View {
    @EnvironmentObject var viewModel: BattleListViewModel
    @Environment(\.scenePhase) var scenePhase
    @Namespace private var animation
    @State var activeID:String?
    @State var showFilterSheet = false
    @State private var selection = RecordSelection<Int64>()

    private var visibleBattleIds: [Int64] {
        viewModel.rows.compactMap { $0.battle?.id }
    }

    var body: some View {
        NavigationStack{
            ScrollViewReader{ proxy in
                VStack {

                    ScrollView{
                        LazyVStack{
                            ForEach(viewModel.rows,id: \.id){row in
                                if row.isBattle {
                                    SelectableRowView(
                                        isSelectionMode: selection.isActive,
                                        isSelected: row.battle.map { selection.contains($0.id) } ?? false,
                                        onTap: {
                                            if let battleId = row.battle?.id {
                                                selection.toggle(battleId)
                                            }
                                        }
                                    ) {
                                        if !selection.isActive, let battle = row.battle {
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
                    RecordSelectionToolbar(
                        selection: $selection,
                        visibleIds: visibleBattleIds,
                        onFavorite: batchToggleFavorite,
                        onDelete: batchDelete,
                        filterButton: AnyView(
                            Button {
                                showFilterSheet = true
                            } label: {
                                Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        )
                    )
                    .matchedTransitionSource(id: "filter", in: animation)
                }
                .sheet(isPresented: $showFilterSheet) {
                    BattleFilterView(showFilterView: $showFilterSheet, filter: $viewModel.filter) {
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
                try await SplatDatabase.shared.dbQueue.write { db in
                    for battleId in selectedBattleIds {
                        if let actualBattle = try Battle.fetchOne(db, key: battleId) {
                            try actualBattle.toggleFavorite()
                        }
                    }
                }
                NotificationCenter.default.post(name: .battleDataChanged, object: nil)
                selection.cancel()
            } catch {
                print("Error batch toggling favorites: \(error)")
            }
        }
    }

    private func batchDelete() {
        let indicatorId = UUID().uuidString
        let selectedBattleIds = Array(selection.selectedIds)
        let totalCount = selectedBattleIds.count

        Task {
            do {
                    // 显示进度提示
                await MainActor.run {
                    Indicators.shared.display(.init(
                        id: indicatorId,
                        icon: .progressIndicator,
                        title: "正在删除",
                        subtitle: "0/\(totalCount)",
                        dismissType: .manual,
                        isUserDismissible: false
                    ))
                }

                    // 批量处理，减少数据库操作次数
                let batchSize = 50 // 每批处理50个
                var processedCount = 0

                for i in stride(from: 0, to: selectedBattleIds.count, by: batchSize) {
                    let endIndex = min(i + batchSize, selectedBattleIds.count)
                    let batch = Array(selectedBattleIds[i..<endIndex])

                        // 批量软删除 - 直接在事务内执行SQL更新
                    try await SplatDatabase.shared.dbQueue.write { db in
                            // Use a single UPDATE statement with IN clause for better performance
                        let placeholders = batch.map { _ in "?" }.joined(separator: ",")
                        let sql = "UPDATE battle SET isDeleted = 1 WHERE id IN (\(placeholders))"
                        let args = StatementArguments(batch)
                        try db.execute(sql: sql, arguments: args)
                    }

                    processedCount += batch.count

                        // 更新进度
                    await MainActor.run {
                        Indicators.shared.updateSubtitle(for: indicatorId, subtitle: "\(processedCount)/\(totalCount)")
                    }

                        // 让出控制权，避免阻塞UI
                    await Task.yield()
                }

                await MainActor.run {
                        // 显示完成提示
                    Indicators.shared.dismiss(with: indicatorId)
                    Indicators.shared.display(.init(
                        id: UUID().uuidString,
                        icon: .systemImage("checkmark.circle.fill"),
                        title: "删除完成",
                        subtitle: "已删除 \(totalCount) 条记录",
                        dismissType: .after(2)
                    ))

                    NotificationCenter.default.post(name: .battleDataChanged, object: nil)
                    selection.cancel()
                }
            } catch {
                await MainActor.run {
                    Indicators.shared.dismiss(with: indicatorId)
                    Indicators.shared.display(.init(
                        id: UUID().uuidString,
                        icon: .systemImage("xmark.circle.fill"),
                        title: "删除失败",
                        subtitle: error.localizedDescription,
                        dismissType: .after(3),
                        style: .error
                    ))
                }
                print("Error batch deleting battles: \(error)")
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
