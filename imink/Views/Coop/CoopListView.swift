import SwiftUI

struct CoopListView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var viewModel: CoopListViewModel
    @State var activeID:String?
    @State var showFilterSheet = false

    var body: some View {
        NavigationStack {
            ScrollView{
                LazyVStack{
                    ForEach(viewModel.rows, id:\.id){ row in
                        NavigationLink{
                            CoopListDetailView(isCoop: row.isCoop, coopId: row.coop?.id, shiftId: row.card?.id)
                        } label:{
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
            .modifier(LoginViewModifier(isLogin: viewModel.isLogin, iconName: "TabBarSalmonRun"))
            .navigationTitle("tab_salmon_run")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: activeID) { oldValue, newValue in
                if newValue == viewModel.rows.last?.id {
                    viewModel.loadMore()
                }
            }
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

        }
        .refreshable {
            await viewModel.fetchCoops()
        }
        .onReceive(mainViewModel.$isLogin) { isLogin in
            viewModel.isLogin = isLogin
        }
        .sheet(isPresented: $showFilterSheet){
            CoopFilterView(showFilterView: $showFilterSheet, filter: $viewModel.filter){
                viewModel.cancel()
                viewModel.loadCoops()
            }
        }
    }

}


#Preview {
    CoopListView()
}
