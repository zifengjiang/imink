import SwiftUI


struct CoopListView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var viewModel: CoopListViewModel
    @Environment(\.scenePhase) var scenePhase
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
                        // 批量操作视图
                    CoopBatchOperationView(
                        selectedCoops: $selectedCoops,
                        isSelectionMode: $isSelectionMode,
                        coops: viewModel.rows.compactMap { $0.coop }
                    )

                    ScrollView{
                        LazyVStack{
                            ForEach(viewModel.rows, id:\.id){ row in
                                    //                                if row.isCoop {
                                if !isSelectionMode {
                                    NavigationLink {
                                        TabView(selection: $selectedRow){
                                            ForEach(viewModel.rows, id:\.id){ row in
                                                CoopListDetailView(isCoop: row.isCoop, coopId: row.coop?.id, shiftId: row.card?.groupId)
                                                    .scrollIndicators(.hidden)
                                                    .scrollClipDisabled()
                                                    .containerRelativeFrame(.horizontal)
                                                    .tag(row.id)
                                            }
                                        }
                                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                        .edgesIgnoringSafeArea(.vertical)
                                        .fixSafeareaBackground()
                                        .onAppear{
                                            selectedRow = row.id
                                            viewModel.loadCurrentCoopFavoriteStatus(for: row.id)
                                        }
                                        .toolbar {

                                            HStack(alignment: .center, spacing: 10){
                                                Button {
                                                    moveToPreviousRow()
                                                    Haptics.generateIfEnabled(self.isFirstRow ? .error : .light)
                                                } label: {
                                                    Image("KEEP")
                                                        .resizable()
                                                        .scaledToFill()
                                                        .rotationEffect(.degrees(180))
                                                        .overlay(self.isFirstRow ? Color(.gray) : Color(.accent))
                                                        .mask{
                                                            Image("KEEP")
                                                                .resizable()
                                                                .scaledToFit()
                                                                .rotationEffect(.degrees(180))
                                                        }
                                                        .frame(width: 20*1.2, height: 10*1.2)
                                                }


                                                Button {
                                                    moveToNextRow()
                                                    Haptics.generateIfEnabled(.light)
                                                } label: {
                                                    Image("KEEP")
                                                        .resizable()
                                                        .scaledToFill()
                                                        .overlay(Color(.accent))
                                                        .mask{
                                                            Image("KEEP")
                                                                .resizable()
                                                                .scaledToFit()
                                                        }
                                                        .frame(width: 20*1.2, height: 10*1.2)
                                                }

                                                Button {
                                                    viewModel.toggleFavorite(for: selectedRow)
                                                    Haptics.generateIfEnabled(.light)
                                                } label: {
                                                    Image(systemName: viewModel.currentCoopIsFavorite ? "heart.fill" : "heart")
                                                        .foregroundColor(viewModel.currentCoopIsFavorite ? .red : .accentColor)
                                                        .font(.system(size: 18))
                                                }

                                                Button{
                                                    Haptics.generateIfEnabled(.medium)
                                                    if let rowId = selectedRow, let coop = viewModel.rows.first(where: {$0.id == rowId})?.coop{
                                                        let image = CoopDetailView(id: coop.id).asUIImage(size: CGSize(width: 400, height: coop.height))
                                                        let activityController = UIActivityViewController(
                                                            activityItems: [image], applicationActivities: nil)
                                                        let vc = UIApplication.shared.windows.first!.rootViewController
                                                        vc?.present(activityController, animated: true)
                                                        AppState.shared.viewModelDict[coop.id] = nil
                                                    }
                                                }label:{
                                                    Image("share")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .overlay(Color(.accent))
                                                        .mask{
                                                            Image("share")
                                                                .resizable()
                                                                .scaledToFit()
                                                        }
                                                        .frame(width: 20*1.2)
                                                        .offset(y:-4)
                                                }
                                            }
                                        }
                                    } label: {
                                        CoopListRowView(row: row)
                                        .id(row.id)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    // 选择模式下的直接显示
                                    CoopListRowView(
                                        row: row,
                                        selectedCoops: self.selectedCoops,
                                        isSelectionMode: isSelectionMode
                                    )
                                    .id(row.id)
                                    .onTapGesture {
                                        if let coopId = row.coop?.id {
                                            if selectedCoops.contains(coopId) {
                                                selectedCoops.remove(coopId)
                                            } else {
                                                selectedCoops.insert(coopId)
                                            }
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
                        ToolbarItem(placement: .navigationBarLeading) {
                            if !isSelectionMode {
                                Button("选择") {
                                    isSelectionMode = true
                                }
                            } else {
                                EmptyView()
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button{
                                showFilterSheet = true
                            } label: {
                                    /// Filter
                                Label("11", systemImage: "line.horizontal.3.decrease.circle")
                            }
                        }
                    }
                    .toolbarTitleMenu {
                        ForEach(CoopRule.allCases, id:\.rawValue){rule in
                            Button{
                                viewModel.filter.rules.removeAll()
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
                    .onChange(of: scenePhase) { oldValue, newPhase in
                        switch newPhase {
                        case .active:
                            TaskManager.shared.start(named: String(describing: Self.self)) {
                                await viewModel.fetchCoops()
                            }
                        default:
                            break
                        }
                    }
                    .onAppear {
                        TaskManager.shared.startLoop(name: String(describing: Self.self), interval: .seconds(300)) {
                            await viewModel.fetchCoops()
                        }
                    }
                }

            }
            .sheet(isPresented: $showFilterSheet){
                CoopFilterView(showFilterView: $showFilterSheet, filter: $viewModel.filter){
                    viewModel.cancel()
                    guard AppState.shared.isLogin else { return }
                    await viewModel.loadCoops()
                }
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

    private func moveToNextRow(){
        if let index = viewModel.rows.firstIndex(where: {$0.id == selectedRow}), index < viewModel.rows.count - 1{
            withAnimation{
                selectedRow = viewModel.rows[index + 1].id
            }
            self.isFirstRow = false
        }
    }

    private func moveToPreviousRow(){
        if let index = viewModel.rows.firstIndex(where: {$0.id == selectedRow}){
            if index > 0{
                withAnimation{
                    selectedRow = viewModel.rows[index - 1].id
                }
            }else{
                self.isFirstRow = true
            }
        }
    }

}


    //#Preview {
    //    CoopListView()
    //}
