import SwiftUI
import SplatNet3API

struct CoopListPage: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @StateObject var viewModel = CoopListViewModel()
    @State var activeID:String?
    var body: some View {
        NavigationStack {
            ScrollView{
                LazyVStack{
                    ForEach(viewModel.rows, id:\.id){ row in
                        if let card = row.card{
                            CoopShiftCardView(card: card)
                        }else if let coop = row.coop {
                            NavigationLink {
                                CoopDetailView(id: coop.id)
                            } label: {
                                CoopListItemView(coop: coop)
                                    .padding(.top, 7.5)
                                    .padding(.bottom, 7)
                                    .padding([.leading, .trailing], 8)
                                    .background(Color(.listItemBackground))
                                    .frame(height: 85)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .padding([.leading, .trailing])
                                    .padding(.top,3)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $activeID, anchor: .bottom)
            .fixSafeareaBackground()
            .modifier(LoginViewModifier(isLogin: viewModel.isLogin, iconName: "TabBarSalmonRun"))
            .navigationTitle("tab_salmon_run")
            .navigationBarTitleDisplayMode(.inline)

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
    CoopListPage()
}
