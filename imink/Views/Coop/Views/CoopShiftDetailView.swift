import SwiftUI
import SplatDatabase

struct CoopShiftDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: CoopListViewModel
    @StateObject var viewModel: CoopShiftDetailViewModel
    @State private var showPlayerDetail: Bool = false
    @State private var activePlayer: CoopPlayerStatus? = nil
    @State private var hoveredMember: Bool = false
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

    var cardView:some View{

        VStack{
            if let coopGroupStatus = viewModel.coopGroupStatus{
                VStack{
                    HStack{
                        VStack(spacing:0){
                            HStack(spacing:10) {
                                CoopRule(rawValue: coopGroupStatus.rule)?.icon
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30)

                                Text(timeSpanText!)
                                    .font(.splatoonFont(size: 15))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.3)
                                    .foregroundStyle(Color.orange)


                            }
                            if let stage = coopGroupStatus._stage{
                                Image(stage.name)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Text(stage.nameId.localizedFromSplatNet)
                                    .font(.splatoonFont(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack{
                            Text("Summary")
                                .font(.splatoonFont(size: 30))
                                .foregroundStyle(Color.orange)
                            if let highestScore = coopGroupStatus.highestScore{
                                Text("最高分\(highestScore)")
                                    .font(.splatoonFont(size: 18))
                                    .foregroundStyle(Color.orange)
                            }
                            HStack{
                                Image(.golden)
                                Text("\(coopGroupStatus.highestEgg)")
                                    .font(.splatoonFont(size: 18))
                                    .foregroundStyle(Color.green)
                            }

                            HStack{
                                var
                            scaleImage:[Image]{[Image(.scale1),Image(.scale2),Image(.scale3)]}
                                var scales:[Int]{
                                    [coopGroupStatus.bronzeScale, coopGroupStatus.silverScale, coopGroupStatus.goldScale]
                                }
                                ForEach(0..<3,id: \.self) { i in
                                    HStack(spacing:0){
                                        scaleImage[i]
                                            .resizable()
                                            .frame(width: 18, height: 18)
                                        Text("\(scales[i])")
                                            .font(.splatoonFont(size: 12))
                                    }
                                }
                            }

                            VStack(alignment: .center){
                                HStack{
                                    Text("Clear:\(coopGroupStatus.clear)")
                                        .foregroundStyle(.waveClear)
                                    Text("Failure:\(coopGroupStatus.failure)")
                                        .foregroundStyle(.waveDefeat)
                                }
                                if coopGroupStatus.disconnect > 0{
                                    Text("Disconnect:\(coopGroupStatus.disconnect)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.splatoonFont(size: 13))
                            Spacer()
                        }
                    }

                    Divider()

                    HStack{
                        Text("发放武器")
                            .font(.splatoonFont(size: 15))
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack{
                            if let suppliedWeapon = coopGroupStatus._suppliedWeapon{
                                ForEach(suppliedWeapon.indices, id: \.self){ i in
                                    VStack{
                                        Image(suppliedWeapon[i].name)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 30, height: 30)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding([.leading, .trailing], 12)
                .padding(.top, 9)
                .padding(.bottom, 8)
                .textureBackground(texture: .bubble, radius: 18)

                VStack { }
                    .frame(maxWidth: .infinity, minHeight: 19, maxHeight: 19)
                    .overlay(
                        GrayscaleTextureView(
                            texture: .bubble,
                            foregroundColor: Color.battleDetailStreakForeground,
                            backgroundColor: Color.listItemBackground
                        )
                        .frame(height: 100)
                        .offset(y: -78)
                        .mask(
                            VStack {
                                HStack {
                                    Spacer()
                                    Image("JobShiftCardTail")
                                        .resizable()
                                        .frame(width: 33, height: 19)
                                }
                                Spacer()
                            }
                                .padding(.trailing, 24)
                        ),
                        alignment: .topLeading
                    )
                    .overlay {
                        HStack(spacing:0){
                            Text("\(coopGroupStatus.count)场打工")
                                .font(.splatoonFont(size: 12))
                                //                        if stats.count != details.count{
                                //                            Text("<\(details.count-stats.count)场掉线>")
                                //                                .inkFont(.font1, size: 10, relativeTo: .body)
                                //                                .foregroundStyle(Color.waveDefeat)
                                //                        }
                        }
                        .foregroundStyle(Color.green)
                        .offset(y:2)
                    }
                    .offset(y: -8)
            }
        }
    }

    var waveView: some View{
        VStack(alignment: .leading){
//            Picker(selection: $viewModel.selectedWave, label: Text("")) {
//                ForEach(viewModel.coopWaveStatus.indices, id: \.self){ index in
//                    if let event = viewModel.coopWaveStatus[index][0].eventWaveGroup{
//                        Text(event.localizedFromSplatNet)
//                            .font(.splatoonFont(size: 15))
//                            .tag(index)
//                    }else{
//                        Text("-")
//                            .font(.splatoonFont(size: 15))
//                            .tag(index)
//                    }
//                }
//            }
//            .labelsHidden()
//            ScrollView(.horizontal, showsIndicators: false) {
            CarouselView(activeIndex: .constant(1), autoScrollDuration: 5){
                    ForEach(viewModel.coopWaveStatus.indices, id: \.self){ index in
                        HStack{
                            ForEach(viewModel.coopWaveStatus[index], id: \.waterLevel){ wave in
                                CoopShiftDetailWaveStatusView(result: wave)
                            }
                        }
                    }
                }
//            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
//            }
            .frame(height: 120)
        }

    }

    var weaponView: some View{
        VStack{
            let columns = Array(repeating: GridItem(.flexible()), count: 8)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.coopWeaponStatus, id: \.nameId){ weapon in
                    VStack(spacing:3){
                        Image(weapon.name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30,height: 30)
                        Text("x\(weapon.count)")
                            .font(.splatoonFont(size: 15))
                    }
                }
            }
        }
        .padding(.all, 10)
        .textureBackground(texture: .bubble, radius: 18)
    }

    var playerView: some View {
        DisclosureGroup{
            let columns = Array(repeating: GridItem(.flexible()), count: 3)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.coopPlayerStatus.indices, id: \.self){ index in
                    VStack{
                        NameplateView(status: viewModel.coopPlayerStatus[index])
                            .overlay {
                                TouchDownAndTouchUpGestureView {
                                    activePlayer = viewModel.coopPlayerStatus[index]
                                    hoveredMember = true
                                } touchMovedCallBack: { distance in
                                    if distance > 10 {
                                        hoveredMember = false
                                    }
                                } touchUpCallBack: {
                                    if hoveredMember {
                                        withAnimation {
                                            showPlayerDetail = true
                                        }
                                        hoveredMember = false
                                    }
                                }
                            }

                            PlayerEncounterIndicator(playerStatus: viewModel.coopPlayerStatus[index])

                    }
                }
            }
        } label: {
            Text("遇到过的工友")
                .font(.splatoonFont(size: 15))
        }
    }

    var kingView:some View{
        HStack{
            let kingSorted = self.viewModel.coopEnemyStatus.filter{$0.nameId.order>=23}
            ForEach(kingSorted,id:\.nameId){king in
                VStack{
                        Image(king.name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                        Text("\(king.totalTeamDefeatCount)/\(king.totalPopCount)")
                            .font(.splatoonFont(size: 12))
                    }

            }

        }
    }

    var enemyView: some View{
        VStack{
            let enemySorted = viewModel.coopEnemyStatus.filter{$0.nameId.order < 23}
            ForEach(enemySorted, id:\.name){boss in
                if boss.name != enemySorted.first?.name{
                    Divider()
                }
                HStack{
                    Image(boss.name)
                        .resizable()
                        .scaledToFit()
                    Text(boss.nameId.localizedFromSplatNet)
                        .font(.splatoonFont(size: 15))
                    Spacer()

                    Text("\(boss.totalTeamDefeatCount)")
                        .font(.splatoonFont(size: 15)) +
                    Text(boss.totalDefeatCount == 0 ? "" : "(\(boss.totalDefeatCount))")
                        .font(.splatoonFont(size: 12))
                    Text("/")
                        .font(.splatoonFont(size: 16))
                    Text("\("appearances_number".localized)x")
                        .font(.splatoonFont(size: 12)) +
                    Text("\(boss.totalPopCount)")
                        .font(.splatoonFont(size: 15))
                }
                .frame(height: 40)

            }
        }
        .padding(.all, 10)
        .textureBackground(texture: .bubble, radius: 18)
    }
}



//#Preview {
//    CoopPlayerStatusView(status: .init(name: "ziFeng", byname: "www", nameId: "4324", nameplate: PackableNumbers([0]), nameplateTextColor: PackableNumbers([0]), uniformId: 1, defeatEnemyCount: 3.4, deliverCount: 4.3, goldenAssistCount: 5.6, goldenDeliverCount: 7.2, rescueCount: 0.2, rescuedCount: 0.3, count: 30, uniformName: "22",_nameplate: .))
//}
