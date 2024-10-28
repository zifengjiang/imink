import SwiftUI
import SplatNet3API
import IndicatorsKit

struct CoopListView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var viewModel: CoopListViewModel
    @State var activeID:String?
    @State var showFilterSheet = false
    @State var selectedRow:String?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView{
                    LazyVStack{
                        ForEach(viewModel.rows, id:\.id){ row in
                            NavigationLink {
                                CoopListDetailView(isCoop: row.isCoop, coopId: row.coop?.id, shiftId: row.card?.groupId)
                            } label: {
                                CoopListRowView(isCoop: row.isCoop, coop: row.coop, card: row.card)
                                    .id(row.id)

                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .refreshable {
                    guard AppState.shared.isLogin else { return }
                    await SN3Client.shared.fetchCoops()
                }
                .scrollPosition(id: $activeID, anchor: .bottom)
                .fixSafeareaBackground()
                .modifier(LoginViewModifier(isLogin: AppState.shared.isLogin, iconName: "TabBarSalmonRun"))
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


#Preview {
    CoopListView()
}
