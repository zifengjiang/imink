import SwiftUI
import SplatDatabase
import Charts

struct HomePage: View {

    @StateObject var viewModel: HomeViewModel

    @State private var vdChartViewHeight: CGFloat = 200
    @State private var vdChartLastBlockWidth: CGFloat = 0

    @State private var mode: GameMode = .regular

    @AppStorage("home_page_selectedScheduleType")
    var selectedScheduleType = 1

    var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {

            ScrollView{
                VStack{
                    TabView {
                        VStack{
                            VStack(spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("今日")
                                        .font(.splatoonFont(size: 22))
                                    Spacer()
                                }
                                if let salmonRunStatus = viewModel.salmonRunStatus{
                                    SalmonRunStatusView(status: salmonRunStatus)
                                }else{
                                    ProgressView()
                                }
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

                                VDGridView(data: viewModel.last500Coop, height: $vdChartViewHeight, lastBlockWidth: $vdChartLastBlockWidth)
                                    .frame(height: vdChartViewHeight)
                            }
                        }

                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 240)

                    scheduleView

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
    
    var scheduleView: some View {
        VStack(spacing: 0){
            Text("home_schedule_title")
                .font(.splatoonFont(size: 22))
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker(selection: $selectedScheduleType) {
                Text("home_picker_battle").tag(1)
                Text("home_picker_salmon_run").tag(2)
            } label: {
                Text("picker")
            }
            .pickerStyle(.segmented)
            .frame(width: 230)
            .padding(.vertical)

//            TabView(selection: $selectedScheduleType) {
//                ScrollView{BattleScheduleView(scheduleGroups: viewModel.scheduleGroups)}.tabItem { Text("Tab Label 1") }.tag(1)
//                ScrollView{SalmonRunScheduleView(salmonRunSchedules: viewModel.salmonRunSchedules)}.tabItem { Text("Tab Label 2") }.tag(2)
//            }

            if selectedScheduleType == 1{
                BattleScheduleView(scheduleGroups: viewModel.scheduleGroups)
            }else{
                SalmonRunScheduleView(salmonRunSchedules: viewModel.salmonRunSchedules)
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

//#Preview(body: {
//    SalmonRunStatusView(status: .init(clear: 30, failure: 2, abort: 2, kill: 21.2, egg: 43.2, rescue: 1.3, rescued: 0.3))
//})
