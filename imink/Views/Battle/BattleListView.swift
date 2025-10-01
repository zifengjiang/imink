import SwiftUI
import SplatDatabase
import GRDB


struct BattleListView: View {
    @EnvironmentObject var viewModel: BattleListViewModel
    @Environment(\.scenePhase) var scenePhase
    @Namespace private var animation
    @State var activeID:String?
    @State var showFilterSheet = false
    @State var isSelectionMode = false
    @State var selectedBattles: Set<Int64> = []
    var body: some View {
        NavigationStack{
            ScrollViewReader{ proxy in
                VStack {

                    ScrollView{
                        LazyVStack{
                            ForEach(viewModel.rows,id: \.id){row in
                                if row.isBattle {
                                    SelectableRowView(
                                        isSelectionMode: isSelectionMode,
                                        isSelected: selectedBattles.contains(row.battle?.id ?? -1),
                                        onTap: {
                                            if let battleId = row.battle?.id {
                                                if selectedBattles.contains(battleId) {
                                                    selectedBattles.remove(battleId)
                                                } else {
                                                    selectedBattles.insert(battleId)
                                                }
                                            }
                                        }
                                    ) {
                                        if !isSelectionMode, let battle = row.battle {
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
                    ToolbarItem(placement: .navigationBarLeading) {
                        if !isSelectionMode {
                            Button("选择") {
                                isSelectionMode = true
                            }
                        } else {
                            HStack(spacing: 12) {
                                Button {
                                    if selectedBattles.count == viewModel.rows.compactMap({ $0.battle }).count {
                                        selectedBattles.removeAll()
                                    } else {
                                        selectedBattles = Set(viewModel.rows.compactMap({ $0.battle }).map { $0.id })
                                    }
                                } label: {
                                    Image(systemName: selectedBattles.count == viewModel.rows.compactMap({ $0.battle }).count ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(.accentColor)
                                }

                                Text("\(selectedBattles.count)")
                                    .font(.splatoonFont(size: 16))
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 20)
                            }
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isSelectionMode {
                            HStack(spacing: 16) {
                                Button {
                                    batchToggleFavorite()
                                } label: {
                                    Image(systemName: "heart")
                                        .foregroundColor(.red)
                                }
                                .disabled(selectedBattles.isEmpty)

                                Button {
                                    batchDelete()
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .disabled(selectedBattles.isEmpty)

                                Button("取消") {
                                    isSelectionMode = false
                                    selectedBattles.removeAll()
                                }
                                .foregroundColor(.accentColor)
                            }
                        } else {
                            Button{
                                showFilterSheet = true
                            } label: {
                                Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        }
                    }
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
        Task {
            do {
                try await SplatDatabase.shared.dbQueue.write { db in
                    for battleId in selectedBattles {
                        if let actualBattle = try Battle.fetchOne(db, key: battleId) {
                            try actualBattle.toggleFavorite()
                        }
                    }
                }
                NotificationCenter.default.post(name: .battleDataChanged, object: nil)
                isSelectionMode = false
                selectedBattles.removeAll()
            } catch {
                print("Error batch toggling favorites: \(error)")
            }
        }
    }

    private func batchDelete() {
        let indicatorId = UUID().uuidString
        let totalCount = selectedBattles.count

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
                let battleIds = Array(selectedBattles)
                let batchSize = 50 // 每批处理50个
                var processedCount = 0

                for i in stride(from: 0, to: battleIds.count, by: batchSize) {
                    let endIndex = min(i + batchSize, battleIds.count)
                    let batch = Array(battleIds[i..<endIndex])

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
                    isSelectionMode = false
                    selectedBattles.removeAll()
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
