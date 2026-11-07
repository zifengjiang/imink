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

                    CarouselView(activeIndex: $selectedScheduleType, autoScrollDuration: 600, userInactivityDelay: 15.0){
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
                        .environmentObject(subscriptionManager)
                }
            })
            .modifier(Popup(isPresented: showStagePreview, onDismiss: {
                showStagePreview = false
            }) {
                if let stage = activeStage {
                    StagePreviewView(stageId: stage.nameId, stageName: stage.name)
                        .environmentObject(subscriptionManager)
                }
            })
            
            .toolbar{
                HomeRefreshButton {
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

/// 首页右上角的刷新按钮：点击后旋转并触发一次赛程拉取。
struct HomeRefreshButton: View {
    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0

    let size: CGFloat = 30
    let task: () async -> Void

    var body: some View {
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
                    await task()
                    isAnimating = false
                    rotationAngle = 0
                }
            }
    }
}
