import SwiftUI
import SplatNet3API

struct CoopListView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var viewModel: CoopListViewModel
    @State var activeID:String?
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
//                    Color.clear
//                        .onAppear {
//                            viewModel.loadMore()
//                        }
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

        }
        .refreshable {
            await SN3Client.shared.fetchCoops()
        }
        .onReceive(mainViewModel.$isLogin) { isLogin in
            viewModel.isLogin = isLogin
        }
    }

}


#Preview {
    CoopListView()
}
