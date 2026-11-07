import SwiftUI
import SplatDatabase

struct CoopDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: CoopListViewModel

    @State var phase:Double = 0
    @StateObject var viewModel: CoopDetailViewModel
    @State private var showPlayerDetail: Bool = false
    @State private var activePlayer: CoopPlayerResult? = nil
    @State private var hoveredMember: Bool = false
    @Binding var navigationPath: NavigationPath

    var id: Int64
    
    init(id: Int64, navigationPath: Binding<NavigationPath>){
        self.id = id
        self._navigationPath = navigationPath
        if let model = AppState.shared.viewModelDict[id]{
            _viewModel = StateObject(wrappedValue: model)
        }else{
            let model = CoopDetailViewModel(id: id)
            _viewModel = StateObject(wrappedValue: model)
        }
    }

    var dangerRateText:String{
        if let dangerRate = viewModel.coop?.dangerRate{
            if dangerRate >= 3.33{
                return "MAX!!"
            }
            return "\(Int(dangerRate*100))%"
        }
        return ""
    }

    var body: some View {
            ScrollView(.vertical){
                HStack {
                    Spacer()
                    VStack(spacing:20){
                        if viewModel.initialized{
                            cardView
                                .padding(.top)
                            waveView
                            memberView
                            enemyView
                                .padding(.bottom)
                        }else{
                            LoadingView(size: 100)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal,8)
            }
            .edgeToEdgeScrollContent()
            .frame(maxWidth: .infinity)
            .fixSafeareaBackground()
            .modifier(Popup(isPresented: showPlayerDetail,
                          onDismiss: {
                showPlayerDetail = false
            }, content: {
                CoopPlayerView(result: activePlayer, onViewPlayerRecords: { playerName, playerByname, playerNameId in
                    // 设置筛选条件
                    listViewModel.filter.playerName = playerName
                    listViewModel.filter.playerByname = playerByname
                    listViewModel.filter.playerNameId = playerNameId
                    listViewModel.navigationTitle = "\(playerName)的打工记录"
                    // 重新加载数据
                    Task {
                        await listViewModel.loadCoops()
                    }

                    // 关闭当前详情页面，返回到列表
                    navigationPath.removeLast(navigationPath.count)
                })
            }))
            .onAppear  {

                AppState.shared.viewModelDict[self.id] = viewModel

                if !viewModel.initialized{
                    print("load Coop \(self.id)")
                    viewModel.load()
                }
            }
            .onDisappear {
                AppState.shared.viewModelDict.removeValue(forKey: self.id)
            }
        }


    var cardView:some View {
        makeCardView()
    }

    var waveView: some View{
        VStack {
            if let coop = viewModel.coop{
                if coop.rule == "TEAM_CONTEST" && viewModel.waveResults.count > 4 {
                    waveResultsView(range: 0..<3)
                    waveResultsView(range: 3..<5)
                } else {
                    waveResultsView(range: viewModel.waveResults.indices)
                }
            }
        }
    }

    var memberView: some View {
        VStack(spacing: 0){
            ForEach(viewModel.playerResults.indices, id: \.self){i in
                if i != 0{
                    Divider()
                }
                CoopDetailMemberView(
                    result: viewModel.playerResults[i],
                    activePlayer: $activePlayer,
                    showPlayerDetail: $showPlayerDetail,
                    hoveredMember: $hoveredMember
                )
            }
        }
        .padding(.all,10)
        .textureBackground(texture: .bubble, radius: 18)
    }

    var enemyView: some View {
        VStack{
            HStack{
                ForEach(viewModel.enemyResults.indices, id: \.self){ i in
                    if viewModel.enemyResults[i].isBoss{
                        VStack{
                            Image(viewModel.enemyResults[i].enemyImage ?? "DummyEnemy")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                            Text(viewModel.enemyResults[i].defeatCount == 1 ? "成功击倒！" : "未能击倒...")
                                .font(.splatoonFont(size: 12))
                            
                        }
                    }
                }
            }

            ForEach(viewModel.enemyResults.indices, id: \.self){ i in
                if !viewModel.enemyResults[i].isBoss{
                    if i != 0{
                        Divider()
                    }
                    makeEnemyView(result: viewModel.enemyResults[i])
                }
            }
        }
        .padding(.all,10)
        .textureBackground(texture: .bubble, radius: 18)
    }
}


