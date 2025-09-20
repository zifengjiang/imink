import SwiftUI
import SplatDatabase

struct CoopListView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var viewModel: CoopListViewModel
    @Environment(\.scenePhase) var scenePhase
    @Namespace private var animation
    @State var activeID:String?
    @State var showFilterSheet = false
    @State var selectedRow:String?
    @State var isFirstRow = true
    @State var isSelectionMode = false
    @State var selectedCoops: Set<Int64> = []


    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack {
                    ScrollView{
                        LazyVStack{
                            ForEach(viewModel.rows, id:\.id){ row in
                                    SelectableRowView(
                                        isSelectionMode: isSelectionMode,
                                        isSelected: selectedCoops.contains(row.coop?.id ?? -1),
                                        onTap: {
                                            if let coopId = row.coop?.id {
                                                if selectedCoops.contains(coopId) {
                                                    selectedCoops.remove(coopId)
                                                } else {
                                                    selectedCoops.insert(coopId)
                                                }
                                            }
                                        }
                                    ) {
                                        if !isSelectionMode {
                                            NavigationLink {
                                                CoopDetailContainer(
                                                    rows: viewModel.rows,
                                                    selectedRow: $selectedRow,
                                                    viewModel: viewModel
                                                )
                                                .environmentObject(viewModel)
                                                .onAppear{
                                                    selectedRow = row.id
                                                    viewModel.loadCurrentCoopFavoriteStatus(for: row.id)
                                                }
                                            } label: {
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
                    .refreshable {
                        TaskManager.shared.start(named: String(describing: Self.self)) {
                            await viewModel.fetchCoops()
                        }
                    }
                    .scrollPosition(id: $activeID, anchor: .bottom)
                    .fixSafeareaBackground()
                    .modifier(LoginViewModifier(isLogin: AppState.shared.isLogin, iconName: "TabBarSalmonRun"))
                    .navigationBarTitle(viewModel.navigationTitle,displayMode: .inline)
//                    .navigationBarTitleDisplayMode(.inline)
                    .onChange(of: activeID) { oldValue, newValue in
                        print("🔍 activeID changed: \(oldValue ?? "nil") -> \(newValue ?? "nil"), isSelectionMode: \(isSelectionMode)")
                        print("🔍 last row id: \(viewModel.rows.last?.id ?? "nil")")
                        if newValue == viewModel.rows.last?.id {
                            print("🔍 Triggering loadMore in selection mode: \(isSelectionMode)")
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
                        ToolbarItem(placement: .navigationBarLeading) {
                            if !isSelectionMode {
                                Button("选择") {
                                    isSelectionMode = true
                                }
                            } else {
                                HStack(spacing: 12) {
                                    Button {
                                        if selectedCoops.count == viewModel.rows.compactMap({ $0.coop }).count {
                                            selectedCoops.removeAll()
                                        } else {
                                            selectedCoops = Set(viewModel.rows.compactMap({ $0.coop }).map { $0.id })
                                        }
                                    } label: {
                                        Image(systemName: selectedCoops.count == viewModel.rows.compactMap({ $0.coop }).count ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(.accentColor)
                                    }
                                    
                                    Text("\(selectedCoops.count)")
                                        .font(.splatoonFont(size: 16))
                                        .foregroundColor(.secondary)
                                        .frame(minWidth: 20)
                                }
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            if isSelectionMode {
                                HStack(spacing: 16) {
                                    Button {
                                        batchToggleFavorite()
                                    } label: {
                                        Image(systemName: "heart")
                                            .foregroundColor(.red)
                                    }
                                    .disabled(selectedCoops.isEmpty)
                                    
                                    Button {
                                        batchDelete()
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .disabled(selectedCoops.isEmpty)
                                    
                                    Button("取消") {
                                        isSelectionMode = false
                                        selectedCoops.removeAll()
                                    }
                                    .foregroundColor(.accentColor)
                                }
                            } else {
                                Button{
                                    showFilterSheet = true
                                } label: {
                                    Label("筛选", systemImage: "line.horizontal.3.decrease.circle")
                                }
                            }
                        }
                        .matchedTransitionSource(id: "filter", in: animation)
                    }
                    .toolbarTitleMenu {
                        ForEach(CoopRule.allCases, id:\.rawValue){ rule in
                            Button{
                                viewModel.filter.clear()
                                if rule != .ALL{
                                    viewModel.filter.rules.insert(rule.rawValue)
                                }
                                viewModel.navigationTitle = rule.name
                                guard AppState.shared.isLogin else { return }
                                Task{
                                    await viewModel.loadCoops()
                                }
                            } label: {
                                Label(
                                    title: { Text("\(rule.name)") },
                                    icon: { rule.icon }
                                )
                            }
                        }

                        Button{
                            viewModel.filter.rules.removeAll()
                            viewModel.navigationTitle = "打工卡片"
                            guard AppState.shared.isLogin else { return }
                            Task{
                                await viewModel.loadCards()
                            }
                        } label: {
                            Label(
                                title: { Text("打工卡片") },
                                icon: { Image(systemName: "creditcard") }
                            )
                        }
                    }
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
            .sheet(isPresented: $showFilterSheet){
                CoopFilterView(showFilterView: $showFilterSheet, filter: $viewModel.filter){
                    viewModel.cancel()
                    guard AppState.shared.isLogin else { return }
                    await viewModel.loadCoops()
                }
                .navigationTransition(.zoom(sourceID: "filter", in: animation))
            }
        }
    }

    struct CustomTabView<Content: View>: View {
        @Binding var selection: String?
        @ViewBuilder var content: () -> Content
        var body: some View {
            ScrollView(.horizontal){
                LazyHStack(spacing: 0){
                    content()
                }
            }
            .scrollPosition(id: $selection)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
        }
    }

    
    private func batchToggleFavorite() {
        Task {
            do {
                for coopId in selectedCoops {
                    if let actualCoop = try await SplatDatabase.shared.dbQueue.read({ db in
                        try Coop.fetchOne(db, key: coopId)
                    }) {
                        try actualCoop.toggleFavorite()
                    }
                }
                
                NotificationCenter.default.post(name: .coopDataChanged, object: nil)
                isSelectionMode = false
                selectedCoops.removeAll()
            } catch {
                print("Error batch toggling favorites: \(error)")
            }
        }
    }
    
    private func checkForLoadMore(rowId: String) {
        print("🔍 Row appeared: \(rowId), last row: \(viewModel.rows.last?.id ?? "nil"), isSelectionMode: \(isSelectionMode)")
        if rowId == viewModel.rows.last?.id {
            print("🔍 Triggering loadMore from onAppear in selection mode: \(isSelectionMode)")
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
        let indicatorId = UUID().uuidString
        let totalCount = selectedCoops.count
        
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
                let coopIds = Array(selectedCoops)
                let batchSize = 50 // 每批处理50个
                var processedCount = 0
                
                for i in stride(from: 0, to: coopIds.count, by: batchSize) {
                    let endIndex = min(i + batchSize, coopIds.count)
                    let batch = Array(coopIds[i..<endIndex])
                    
                    // 批量软删除 - 直接在事务内执行SQL更新
                    try await SplatDatabase.shared.dbQueue.write { db in
                        for coopId in batch {
                            try db.execute(sql: "UPDATE coop SET isDeleted = 1 WHERE id = ?", arguments: [coopId])
                        }
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
                    
                    NotificationCenter.default.post(name: .coopDataChanged, object: nil)
                    isSelectionMode = false
                    selectedCoops.removeAll()
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
                print("Error batch deleting coops: \(error)")
            }
        }
    }

}


    //#Preview {
    //    CoopListView()
    //}
