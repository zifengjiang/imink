import SwiftUI
import SplatNet3API
import IndicatorsKit

struct CoopListView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var viewModel: CoopListViewModel
    @State var activeID:String?
    @State var showFilterSheet = false
    @State var selectedRow:String = ""

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView{
                    LazyVStack{
                        ForEach(viewModel.rows, id:\.id){ row in
                            NavigationLink {
                                DetailTabView(selectedRow: $selectedRow, rows: $viewModel.rows)
                                    .onAppear {
                                        selectedRow = row.id
                                    }
                                    .toolbar {
                                        ToolbarItem {
                                            Button{
                                                // select previous row if has one
                                                if viewModel.rows.firstIndex(where: {$0.id == selectedRow})! > 0{
                                                    withAnimation{
                                                        selectedRow = viewModel.rows[viewModel.rows.firstIndex(where: {$0.id == selectedRow})! - 1].id
                                                    }
                                                }

                                            } label: {
                                                    /// Filter
                                                Label("11", systemImage: "arrowtriangle.left.fill")
                                            }
                                        }
                                        ToolbarItem {
                                            Button{
                                                // select next row if has one
                                                if viewModel.rows.firstIndex(where: {$0.id == selectedRow})! < viewModel.rows.count - 1{
                                                    withAnimation{
                                                        selectedRow = viewModel.rows[viewModel.rows.firstIndex(where: {$0.id == selectedRow})! + 1].id
                                                    }
                                                }
                                            } label: {
                                                    /// Filter
                                                Label("11", systemImage: "arrowtriangle.right.fill")
                                            }
                                        }
                                    }
                            } label: {
                                CoopListRowView(isCoop: row.isCoop, coop: row.coop, card: row.card)
                                    .id(row.id)

                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $activeID, anchor: .bottom)
                .fixSafeareaBackground()
                    //            .modifier(LoginViewModifier(isLogin: viewModel.isLogin, iconName: "TabBarSalmonRun"))
                .navigationTitle(viewModel.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: activeID) { oldValue, newValue in
                    if newValue == viewModel.rows.last?.id {
                        Task{
                            await viewModel.loadMore()
                        }
                    }
                }
                .onChange(of: selectedRow, { oldValue, newValue in
                    proxy.scrollTo(newValue,anchor: .center)
                })
                .toolbar {
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
                }
            }

        }
        .refreshable {
            await SN3Client.shared.fetchCoops()
        }
        .onReceive(mainViewModel.$isLogin) { isLogin in
            viewModel.isLogin = isLogin
        }
        .sheet(isPresented: $showFilterSheet){
            CoopFilterView(showFilterView: $showFilterSheet, filter: $viewModel.filter){
                viewModel.cancel()
                await viewModel.loadCoops()
            }
        }
    }

    struct DetailTabView:View {
        @Binding var selectedRow: String
        @Binding var rows:[CoopListRowModel]
        var body: some View {

            TabView(selection: $selectedRow) {
                ForEach(rows, id:\.id){ row in
                    CoopListDetailView(isCoop: row.isCoop, coopId: row.coop?.id, shiftId: row.card?.groupId)
                        .tag(row.id)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.vertical)
            .fixSafeareaBackground()
        }
    }

}


#Preview {
    CoopListView()
}
