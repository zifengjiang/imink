import SwiftUI
import SplatDatabase
import Charts

struct HomePage: View {

    @StateObject var viewModel: HomeViewModel
    @EnvironmentObject var subscriptionManager: ScheduleSubscriptionManager

    @State private var vdChartViewHeight: CGFloat = 200
    @State private var vdChartLastBlockWidth: CGFloat = 0

    @State private var mode: GameMode = .regular
    @State private var showSubscribedOnly = false
    
    // 场地预览弹窗状态管理
    @State private var showStagePreview = false
    @State private var activeStage: ImageMap? = nil
    @State private var hoveredStage: Bool = false
    
    // Coop场地预览弹窗状态管理
    @State private var showCoopStagePreview = false
    @State private var activeCoopStage: ImageMap? = nil
    @State private var hoveredCoopStage: Bool = false

    @AppStorage("home_page_selectedScheduleType")
    var selectedScheduleType = 0

    var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {

            ScrollView{
                VStack{

                    CarouselView(activeIndex: $selectedScheduleType, autoScrollDuration: 60){
                            todayBattleStatusView
                            todaySalmonRunStatusView
                    }
                    .modifier(LoginViewModifier(isLogin: AppState.shared.isLogin, iconName: "TabBarHome"))
                    .frame(height: 240)

                    VStack(spacing:0){
                        HStack {
                            Text("home_schedule_title")
                                .font(.splatoonFont(size: 22))
                            
                            Spacer()
                            
                            // 筛选按钮
                            Button(action: {
                                showSubscribedOnly.toggle()
                                Haptics.generateIfEnabled(.light)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: showSubscribedOnly ? "bell.fill" : "bell")
                                        .font(.system(size: 14, weight: .medium))
                                    // Text(showSubscribedOnly ? "已订阅" : "全部")
                                    //     .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(showSubscribedOnly ? .orange : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(showSubscribedOnly ? Color.orange.opacity(0.1) : Color.secondary.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Picker(selection: $selectedScheduleType) {
                            Text("home_picker_battle").tag(0)
                            Text("home_picker_salmon_run").tag(1)
                        } label: {
                            Text("picker")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 230)
                        .padding(.vertical)

                        
                        if selectedScheduleType == 0{
                            BattleScheduleView(
                                scheduleGroups: showSubscribedOnly ? 
                                    subscriptionManager.filterSubscribedBattleSchedules(viewModel.scheduleGroups) : viewModel.scheduleGroups,
                                showStagePreview: $showStagePreview,
                                activeStage: $activeStage,
                                hoveredStage: $hoveredStage
                            )
                        }else{
                            SalmonRunScheduleView(
                                salmonRunSchedules: showSubscribedOnly ? 
                                    subscriptionManager.filterSubscribedSalmonRunSchedules(viewModel.salmonRunSchedules) : viewModel.salmonRunSchedules,
                                showCoopStagePreview: $showCoopStagePreview,
                                activeCoopStage: $activeCoopStage,
                                hoveredCoopStage: $hoveredCoopStage
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .fixSafeareaBackground()
            .navigationBarTitle("tab_home", displayMode: .inline)
            .modifier(Popup(isPresented: showCoopStagePreview, onDismiss: {
                showCoopStagePreview = false
            }) {
                if let stage = activeCoopStage {
                    CoopStagePreviewView(stageId: stage.nameId, stageName: stage.name)
                }
            })
            .modifier(Popup(isPresented: showStagePreview, onDismiss: {
                showStagePreview = false
            }) {
                if let stage = activeStage {
                    StagePreviewView(stageId: stage.nameId, stageName: stage.name)
                }
            })
            
            .toolbar{
                LoadingView {
                    Haptics.generateIfEnabled(.medium)
                    await viewModel.fetchSchedules()
                }
            }
            .task {
                await viewModel.fetchSchedules()
            }
            .onReceive(timer) { currentTime in
                if let endTime = viewModel.schedules.filter({$0.mode != .salmonRun}).first?.endTime, currentTime > endTime{
                    Task{
                        await viewModel.fetchSchedules()
                    }
                }
            }
        }
    }

    struct LoadingView: View {
        @State private var isAnimating = false
        @State private var rotationAngle: Double = 0
        let size:CGFloat = 30
        let task: () async -> ()
        var body: some View {
            // 加载状态的图标，带有旋转效果
            Image("TabBarHome")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.accent)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotationAngle))
                .animation(isAnimating ? .linear(duration: 2) : nil, value: rotationAngle)
                .onTapGesture {
                    Task {
                        isAnimating = true
                        rotationAngle = 720
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isAnimating = false
                            rotationAngle = 0
                        }
                        await self.task()

                    }
                }
        }

    }


    var todaySalmonRunStatusView: some View{
        VStack{
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("最近工况")
                        .font(.splatoonFont(size: 22))
                    if let lastCoopTime = viewModel.lastCoopTime{
                        Text("更新于: \(lastCoopTime.toPlayedTimeString())")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                SalmonRunStatusView(status: viewModel.salmonRunStatus ?? CoopGroupStatus.defaultValue, coopSummary: CoopSummary.value)
            }
            .padding(.top)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("近期工况")
                        .font(.splatoonFont(size: 22))
                        .foregroundStyle(Color.appLabel)

                    Text("(\(NSLocalizedString("最近500场", comment: "")))")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                HStack {
                    Spacer()
                    Text("最近50场")
                        .font(.splatoonFont(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                        .frame(width: vdChartLastBlockWidth)
                }
                .frame(height: 20)

                VDGridView(data: viewModel.last500Coop, isCoop: true, height: $vdChartViewHeight, lastBlockWidth: $vdChartLastBlockWidth)
                    .frame(height: vdChartViewHeight)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    var todayBattleStatusView: some View{
        VStack{
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("最近战况")
                        .font(.splatoonFont(size: 22))
                    if let lastPlayTime = viewModel.battleStatus?.endTime{
                        Text("更新于: \(lastPlayTime.toPlayedTimeString())")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                BattleStatusView(today: viewModel.battleStatus ?? BattleGroupStatus.defaultValue)

            }
            .padding(.top)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("近期战况")
                        .font(.splatoonFont(size: 22))
                        .foregroundStyle(Color.appLabel)

                    Text("(\(NSLocalizedString("最近500场", comment: "")))")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                HStack {
                    Spacer()
                    Text("最近50场")
                        .font(.splatoonFont(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                        .frame(width: vdChartLastBlockWidth)
                }
                .frame(height: 20)

                VDGridView(data: viewModel.last500Battle, isCoop:false, height: $vdChartViewHeight, lastBlockWidth: $vdChartLastBlockWidth)
                    .frame(height: vdChartViewHeight)
            }
        }
    }

    struct BattleScheduleView: View {
        let scheduleGroups: [Date: [Schedule]]
        @Binding var showStagePreview: Bool
        @Binding var activeStage: ImageMap?
        @Binding var hoveredStage: Bool
        
        var body: some View {
            VStack{
                ForEach(scheduleGroups.keys.sorted(), id: \.self){ key in
                    BattleScheduleCardView(
                        schedules: scheduleGroups[key]!,
                        showStagePreview: $showStagePreview,
                        activeStage: $activeStage,
                        hoveredStage: $hoveredStage
                    )
                }
            }
            .padding(.bottom, 10)
        }
    }

    struct SalmonRunScheduleView: View {
        let salmonRunSchedules: [Schedule]
        @Binding var showCoopStagePreview: Bool
        @Binding var activeCoopStage: ImageMap?
        @Binding var hoveredCoopStage: Bool
        
        var body: some View {
            VStack{
                ForEach(salmonRunSchedules.indices, id: \.self){ index in
                    SalmonRunScheduleCardView(
                        schedule: salmonRunSchedules[index],
                        showCoopStagePreview: $showCoopStagePreview,
                        activeCoopStage: $activeCoopStage,
                        hoveredCoopStage: $hoveredCoopStage
                    )
                }
            }
            .padding(.bottom, 10)
        }
    }
}

struct SalmonRunStatusView:View {
    let status:CoopGroupStatus
    let coopSummary:CoopSummary?

    var body: some View {

        GeometryReader{ geometry in
            CarouselView(activeIndex: .constant(1), autoScrollDuration: 150) {
                HStack(spacing:8){
                    VStack{
                        HStack{
                            Chart {
                                SectorMark(angle: .value("1", status.disconnect))
                                    .foregroundStyle(Color.gray)
                                SectorMark(angle: .value("2", status.failure))
                                    .foregroundStyle(Color.waveDefeat)
                                SectorMark(angle: .value("3", status.clear))
                                    .foregroundStyle(Color.waveClear)
                            }
                            .opacity(0.8)
                            .frame(width: 25, height: 25)

                            Text("通关率")
                                .font(.splatoonFont(size: 16))

                            Text("\(status.clearRate*100, places: 3)%")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.secondary)
                        }

                        HStack{
                            Spacer()

                            VStack{
                                Text("Clear")
                                    .font(.splatoonFont(size: 10))
                                    .foregroundStyle(.secondary)
                                Text("\(status.clear)")
                                    .font(.splatoonFont(size: 24))
                                    .foregroundStyle(.waveClear)
                            }

                            Spacer()

                            VStack{
                                Text("Failure")
                                    .font(.splatoonFont(size: 10))
                                    .foregroundStyle(.secondary)
                                Text("\(status.failure)")
                                    .font(.splatoonFont(size: 24))
                                    .foregroundStyle(.waveDefeat)
                            }

                            Spacer()

                            if status.disconnect != 0 {
                                VStack{
                                    Text("Disconnect")
                                        .font(.splatoonFont(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text("\(status.disconnect)")
                                        .font(.splatoonFont(size: 24))
                                        .foregroundStyle(.waveDefeat)
                                }

                                Spacer()
                            }
                        }

                    }
                    .frame(width: geometry.size.width/2 - 4)
                    .padding([.top,.bottom],5)
                    .frame(height: geometry.size.height)
                    .background(Color.listItemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))


                    VStack(alignment: .leading){
                        HStack{
                            CoopListShiftCardView.StatusView(status: status, hSpace: 0, vSpace: 3)
                            if let weapons = status._suppliedWeapon {
                                LazyHGrid(rows: [GridItem(.adaptive(minimum: 20)),GridItem(.adaptive(minimum: 20))], spacing: 2){
                                    ForEach(weapons.indices, id: \.self){ index in
                                        Image(weapons[index].name)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20,height: 20)
                                    }
                                }
                            }
                        }

                        if let point = coopSummary?.pointCard.regularPoint{
                            Text("现有点数 \(point)p")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.waveClear)
                        }
                    }
                    .frame(width: geometry.size.width/2 - 4)
                    .padding([.top,.bottom],5)
                    .frame(height: geometry.size.height)
                    .background(Color.listItemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))



                }
                .frame(maxWidth: .infinity)

                HStack(spacing:8){
                    VStack(spacing:1){
                        Text("鳞片")
                            .font(.splatoonFont(size: 16))
                            .foregroundStyle(Color(.spGreen))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.leading, 8)
                        HStack{
                            VStack(spacing: 1){
                                Image(.scale1)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                Text("x\(coopSummary?.scale.bronze ?? 0)")
                                    .font(.splatoonFont(size: 16))
                            }
                            VStack(spacing: 1){
                                Image(.scale2)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                Text("x\(coopSummary?.scale.silver ?? 0)")
                                    .font(.splatoonFont(size: 16))
                            }

                            VStack(spacing: 1){
                                Image(.scale3)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                Text("x\(coopSummary?.scale.gold ?? 0)")
                                    .font(.splatoonFont(size: 16))
                            }
                        }
                    }
                    .frame(width: geometry.size.width/2 - 4)
                    .padding([.top,.bottom],5)
                    .frame(height: geometry.size.height)
                    .background(Color.listItemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading,spacing: 2){
                        if let gradeName = coopSummary?.regularGrade, let gradePoint = coopSummary?.regularGradePoint{
                            Text("\(gradeName.localizedFromSplatNet) \(gradePoint)")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(Color.waveClear)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 6)
                            ProgressBar(fillPercentage: gradePoint >= 100 ? 1 : Double(gradePoint)/Double(100))
                                .padding(.horizontal,8)
                                .padding(.vertical, 2)
                        }

                        Text("平均通关的WAVE数")
                            .font(.splatoonFont(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                        Text("\(coopSummary?.regularAverageClearWave ?? 0, places: 1)")
                            .font(.splatoonFont(size: 20))
                            .foregroundStyle(.waveClear)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 8)
                    }
                    .frame(width: geometry.size.width/2 - 4)
                    .padding([.top,.bottom],5)
                    .frame(height: geometry.size.height)
                    .background(Color.listItemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    
                }
                .frame(maxWidth: .infinity)

                if let pointCard = coopSummary?.pointCard{
                    HStack(spacing:8){
                        VStack{
                            HStack {
                                Spacer()
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("打工次数")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                    Text("已收集的金鲑鱼卵")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                    Text("已收集的鲑鱼卵")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 10) {
                                    Text("\(pointCard.playCount)")
                                        .font(.splatoonFont(size: 12))
                                    Text("\(pointCard.goldenDeliverCount)")
                                        .font(.splatoonFont(size: 12))
                                    Text("\(pointCard.deliverCount)")
                                        .font(.splatoonFont(size: 12))
                                }
                                Spacer()
                            }

                        }
                        .frame(width: geometry.size.width/2 - 4)
                        .padding([.top,.bottom],5)
                        .frame(height: geometry.size.height)
                        .background(Color.listItemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack{
                            HStack {
                                Spacer()
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("击退头目鲑鱼的次数")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                    Text("救援次数")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                    Text("累计点数")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 10) {
                                    Text("\(pointCard.defeatBossCount)")
                                        .font(.splatoonFont(size: 12))
                                    Text("\(pointCard.rescueCount)")
                                        .font(.splatoonFont(size: 12))
                                    Text("\(pointCard.totalPoint)")
                                        .font(.splatoonFont(size: 12))
                                }
                                Spacer()
                            }

                        }
                        .frame(width: geometry.size.width/2 - 4)
                        .padding([.top,.bottom],5)
                        .frame(height: geometry.size.height)
                        .background(Color.listItemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

        }
    }

}

struct BattleStatusView: View {

    let today: BattleGroupStatus

    @AppStorage("showKDInHome")
    private var showKD: Bool = false

    var body: some View {
        HStack(spacing: 8) {

            VStack {
                HStack {

                    Chart {
                        SectorMark(angle: .value("1", today.disconnectCount))
                            .foregroundStyle(Color.gray)
                        SectorMark(angle: .value("2", today.loseCount))
                            .foregroundStyle(Color.waveDefeat)
                        SectorMark(angle: .value("3", today.winCount))
                            .foregroundStyle(Color.waveClear)
                    }
                    .opacity(0.9)
                    .frame(width: 25, height: 25)

                    Text("胜率")
                        .font(.splatoonFont(size: 16))
                        .foregroundStyle(.appLabel)
                        .minimumScaleFactor(0.5)

                    Text("\(today.victoryRate*100, places: 2)%")
                        .font(.splatoonFont(size: 16))
                        .foregroundStyle(.secondary)

                }

                HStack {

                    Spacer()

                    VStack(spacing: 4) {

                        Text("胜利")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)

                        Text("\(today.winCount)")
                            .font(.splatoonFont(size: 24))
                            .foregroundStyle(.waveClear)
                            .minimumScaleFactor(0.5)


                    }

                    Spacer()

                    VStack(spacing: 4) {

                        Text("失败")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)

                        Text("\(today.loseCount)")
                            .font(.splatoonFont(size: 24))
                            .foregroundStyle(Color.pink.opacity(0.8))
                            .minimumScaleFactor(0.5)

                    }

                    Spacer()

                    VStack(spacing: 4) {

                        Text("平局")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)

                        Text("\(today.drawCount)")
                            .font(.splatoonFont(size: 24))
                            .foregroundStyle(Color.pink.opacity(0.8))
                            .minimumScaleFactor(0.5)

                    }

                    Spacer()

                    VStack(spacing: 4) {

                        Text("掉线")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)

                        Text("\(today.disconnectCount)")
                            .font(.splatoonFont(size: 24))
                            .foregroundStyle(Color.pink.opacity(0.8))
                            .minimumScaleFactor(0.5)

                    }


                    Spacer()

                }
            }
            .padding([.top,.bottom],5)
            .background(.listItemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            ZStack {
                VStack {
                    HStack {

                        if showKD {

                            Chart {
                                SectorMark(angle: .value("1", today.kill))
                                    .foregroundStyle(Color.red)
                                SectorMark(angle: .value("2", today.death))
                                    .foregroundStyle(Color.gray.opacity(0.5))

                            }
                            .opacity(0.9)
                            .frame(width: 25, height: 25)

                            Text("K/D:")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.appLabel)

                            Text("\(today.kd, places: 1)")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.secondary)
                        } else {

                            Chart {
                                SectorMark(angle: .value("1", today.kill))
                                    .foregroundStyle(Color.red)
                                SectorMark(angle: .value("2", today.assist))
                                    .foregroundStyle(Color.red.opacity(0.8))
                                SectorMark(angle: .value("3", today.death))
                                    .foregroundStyle(Color.gray.opacity(0.5))
                            }
                            .opacity(0.9)
                            .frame(width: 25, height: 25)

                            Text("KA/D:")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.appLabel)

                            Text("\(today.kad, places: 1)")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.secondary)
                        }

                    }

                    HStack {

                        Spacer()

                        VStack(spacing: 4) {

                            if showKD {
                                Text("KILL")
                                    .font(.splatoonFont(size: 10))
                                    .foregroundStyle(.secondary)

                                Text("\(today.kill)")
                                    .font(.splatoonFont(size: 24))
                                    .foregroundStyle(.red)
                                    .minimumScaleFactor(0.5)
                            } else {
                                Text("KILL+ASSIST")
                                    .font(.splatoonFont(size: 10))
                                    .foregroundStyle(.secondary)

                                Text("\(today.kill + today.assist)")
                                    .font(.splatoonFont(size: 24))
                                    .foregroundStyle(.red)
                                    .minimumScaleFactor(0.5)
                            }

                        }

                        Spacer()

                        VStack(spacing: 4) {

                            Text("DEATH")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)

                            Text("\(today.death)")
                                .font(.splatoonFont(size: 24))
                                .foregroundStyle(.gray.opacity(0.5))
                                .minimumScaleFactor(0.5)

                        }

                        Spacer()

                    }
                }
                .padding([.top,.bottom],5)
                .background(.listItemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack {
                    HStack {
                        Spacer()

                        Image(systemName: showKD ? "circle" : "largecircle.fill.circle")
                            .resizable()
                            .frame(width: 14, height: 14)
                            .foregroundColor(Color.gray.opacity(0.3))
                            .padding([.trailing, .top], 6)
                    }

                    Spacer()
                }
            }
            .onTapGesture {
                showKD.toggle()
            }

        }
        .frame(maxWidth: .infinity)

    }
}




//#Preview(body: {
//    SalmonRunStatusView(status: .init(clear: 30, failure: 2, abort: 2, kill: 21.2, egg: 43.2, rescue: 1.3, rescued: 0.3))
//})
