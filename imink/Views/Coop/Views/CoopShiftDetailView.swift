import SwiftUI
import SplatDatabase

struct CoopShiftDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: CoopListViewModel
    @StateObject var viewModel: CoopShiftDetailViewModel
    @State var showPlayerDetail: Bool = false
    @State var activePlayer: CoopPlayerStatus? = nil
    @State var hoveredMember: Bool = false
    @Binding var navigationPath: NavigationPath

    var id: Int
    init(id: Int, navigationPath: Binding<NavigationPath>){
        self.id = id
        self._navigationPath = navigationPath
        _viewModel = StateObject(wrappedValue: CoopShiftDetailViewModel(id: id))
    }

    var body: some View {
        VStack{
            if viewModel.initialized{
                ScrollView{
                    HStack {
                        Spacer()
                        VStack(spacing:20){
                            
                            cardView
                                .padding(.top)
                            waveView

                            kingView
                            enemyView

                            weaponView
                            playerView
                                .padding(.bottom)

                        }
                        Spacer()
                    }
                    .padding(.horizontal,8)
                }
            }else{
                LoadingView(size: 100)
            }
        }
        .edgeToEdgeScrollContent()
        .frame(maxWidth: .infinity)
        .fixSafeareaBackground()
        .modifier(Popup(isPresented: showPlayerDetail,
                       onDismiss: {
            showPlayerDetail = false
        }, content: {
            CoopPlayerStatusView(status: activePlayer, onViewPlayerRecords: { playerName, playerByname, playerNameId in
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
        .task  {
            print("load Shift \(self.id)")
           await viewModel.load()
        }
    }

    var timeSpanText: String? {
        guard let coopGroupStatus = viewModel.coopGroupStatus else { return nil }
        return DateFormat.yearMonthDayHourMinute.string(from: coopGroupStatus.startTime)
            + " - "
            + DateFormat.yearMonthDayHourMinute.string(from: coopGroupStatus.endTime)
    }

}

//#Preview {
//    CoopPlayerStatusView(status: .init(name: "ziFeng", byname: "www", nameId: "4324", nameplate: PackableNumbers([0]), nameplateTextColor: PackableNumbers([0]), uniformId: 1, defeatEnemyCount: 3.4, deliverCount: 4.3, goldenAssistCount: 5.6, goldenDeliverCount: 7.2, rescueCount: 0.2, rescuedCount: 0.3, count: 30, uniformName: "22",_nameplate: .))
//}
