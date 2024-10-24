import SwiftUI
import SplatDatabase
import Charts

struct HomePage: View {

    @StateObject var viewModel: HomeViewModel

    @State private var vdChartViewHeight: CGFloat = 200
    @State private var vdChartLastBlockWidth: CGFloat = 0

    @State private var mode: GameMode = .regular

    @AppStorage("home_page_selectedScheduleType")
    var selectedScheduleType = 0

    var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {

            ScrollView{
                VStack{

                    CarouselView(activeIndex: $selectedScheduleType, autoScrollDuration: 15){
//                        if selectedScheduleType == 1{
                            todayBattleStatusView
////                        }else{
                            todaySalmonRunStatusView
//                        }
                    }
                    .modifier(LoginViewModifier(isLogin: AppState.shared.isLogin, iconName: "TabBarHome"))
                    .frame(height: 240)



                    VStack(spacing:0){
                        Text("home_schedule_title")
                            .font(.splatoonFont(size: 22))
                            .frame(maxWidth: .infinity, alignment: .leading)

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
                            BattleScheduleView(scheduleGroups: viewModel.scheduleGroups)
                        }else{
                            SalmonRunScheduleView(salmonRunSchedules: viewModel.salmonRunSchedules)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .fixSafeareaBackground()
            .navigationBarTitle("tab_home", displayMode: .inline)
            .toolbar{
                Button {
                    Task{
                        await viewModel.fetchSchedules()
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .frame(width: 22, height: 22)
                }

            }
            .task {
                await viewModel.fetchSchedules()
//                await viewModel.loadLastSalmonRunStatus()
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
                    Spacer()
                }

                SalmonRunStatusView(status: viewModel.salmonRunStatus ?? CoopGroupStatus.defaultValue)
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
            }
        }
    }

    var todayBattleStatusView: some View{
        VStack{
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("最近战况")
                        .font(.splatoonFont(size: 22))
                    Text("\(viewModel.battleStatus?.lastPlayTime ?? Date())")
                        .font(.splatoonFont(size: 10))
                        .foregroundStyle(.secondary)
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
        var body: some View {
            VStack{
                ForEach(scheduleGroups.keys.sorted(), id: \.self){ key in
                    BattleScheduleCardView(schedules: scheduleGroups[key]!)
                }
            }
        }
    }

    struct SalmonRunScheduleView: View {
        let salmonRunSchedules: [Schedule]
        var body: some View {
            VStack{
                ForEach(salmonRunSchedules.indices, id: \.self){ index in
                    SalmonRunScheduleCardView(schedule: salmonRunSchedules[index])
                }
            }
        }
    }
}

struct SalmonRunStatusView:View {
    let status:CoopGroupStatus

    var body: some View {

        GeometryReader{ geometry in
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
                    CoopListShiftCardView.StatusView(status: status, hSpace: 0, vSpace: 3)
                    if let weapons = status._suppliedWeapon {
                        HStack{
                            ForEach(weapons.indices, id: \.self){ index in
                                Image(weapons[index].name)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20,height: 20)
                            }
                        }
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

struct BattleStatusView: View {

    let today: BattleGroupStatus

    @AppStorage("showKDInHome")
    private var showKD: Bool = false

    var body: some View {
        HStack(spacing: 8) {

            VStack {
                HStack {

                    Chart {
                        SectorMark(angle: .value("1", today.disconnect))
                            .foregroundStyle(Color.gray)
                        SectorMark(angle: .value("2", today.defeat))
                            .foregroundStyle(Color.waveDefeat)
                        SectorMark(angle: .value("3", today.victory))
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

                        Text("\(today.victory)")
                            .font(.splatoonFont(size: 24))
                            .foregroundStyle(.waveClear)
                            .minimumScaleFactor(0.5)


                    }

                    Spacer()

                    VStack(spacing: 4) {

                        Text("失利")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)

                        Text("\(today.defeat)")
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
