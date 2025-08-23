import SwiftUI
import SplatDatabase

struct BattleScheduleCardView: View {
    var schedules: [Schedule]
    @EnvironmentObject private var subscriptionManager: ScheduleSubscriptionManager

    var body: some View {
        VStack{
            VStack{
                if let startTime = schedules.first?.startTime, startTime < Date(){
                    Text("Now")
                        .font(.splatoonFont(size: 15))
                        .colorInvert()
                }else{
                    Text(schedules.first!.formattedBattleTime)
                        .font(.splatoonFont(size: 15))
                        .colorInvert()
                }
            }
            .padding(3)
            .padding(.horizontal)
            .background(Color.secondary)
            .clipShape(Capsule())
            .padding(.bottom, 5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack{
                    ForEach(schedules, id: \.id){ schedule in
                        if schedule.mode == .fest || schedule.mode == .bankara{
                            CardColumn(schedule: schedule, mode: schedule.mode, rule: schedule.rule1, stages: schedule.challengeStage, isOpen: false)
                                .environmentObject(subscriptionManager)
                            CardColumn(schedule: schedule, mode: schedule.mode, rule: schedule.rule2!, stages: schedule.openStage, isOpen: true)
                                .environmentObject(subscriptionManager)
                        }else{
                            CardColumn(schedule: schedule, mode: schedule.mode, rule: schedule.rule1, stages: schedule._stage, event: schedule.event)
                                .environmentObject(subscriptionManager)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.listItemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    struct CardColumn:View {
        let schedule: Schedule
        let mode:Schedule.Mode
        let rule:Schedule.Rule
        let stages: [ImageMap]
        let event:String?
        let isOpen:Bool
        
        @EnvironmentObject private var subscriptionManager: ScheduleSubscriptionManager

        init(schedule: Schedule, mode: Schedule.Mode, rule: Schedule.Rule, stages: [ImageMap], event: String? = nil, isOpen:Bool = false) {
            self.schedule = schedule
            self.mode = mode
            self.rule = rule
            self.stages = stages
            self.event = event
            self.isOpen = isOpen
        }
        
        private var subscription: ScheduleSubscription {
            // 对于bankara和fest模式使用特定的规则和场地
            if (schedule.mode == .bankara || schedule.mode == .fest) && rule != schedule.rule1 {
                return subscriptionManager.createSubscription(from: schedule, specificRule: rule, stages: stages, isOpen: isOpen)
            } else {
                return subscriptionManager.createSubscription(from: schedule)
            }
        }
        
        private var isSubscribed: Bool {
            subscriptionManager.isSubscribed(subscription.id)
        }

        var body: some View {
            ZStack {
                VStack(alignment: .center, spacing: 8){
                    HStack(spacing:2){
                        if mode == .fest{
                            FestIcon()
                                .frame(width: 12, height: 12)
                        }else{
                            mode.icon
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                        }

                        if mode == .bankara || mode == .x || mode == .event{
                            rule.icon
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                        }

                        if mode == .event{
                            Text(event!.localizedFromSplatNet)
                                .font(.splatoonFont(size: 12))
                                .lineLimit(1)
                                .minimumScaleFactor(0.1)
                        }else{
                            Text(mode.localized(open: isOpen))
                                .font(.splatoonFont(size: 12))
                                .lineLimit(1)
                                .minimumScaleFactor(0.1)
                        }
                    }

                    ForEach(stages.indices, id:\.self) { index in

                        Text(stages[index].nameId.localizedFromSplatNet)
                            .font(.splatoonFont(size: 12))
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)

                        Image(stages[index].name)
                            .resizable()
                            .aspectRatio(640 / 360, contentMode: .fill)
                            .frame(width: 640 / 6, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(UIColor.separator), lineWidth: 1)
                            )
                    }
                }
                .frame(width: 640 / 6)
                
                // 订阅状态指示器
                if isSubscribed {
                    VStack {
                        HStack {
                            Spacer()
                            subscriptionIndicator
                        }
                        Spacer()
                    }
                    .frame(width: 640 / 6)
                }
            }
            .contextMenu {
                contextMenuContent
            }
        }
        
        private var subscriptionIndicator: some View {
            Image(systemName: "bell.fill")
                .foregroundColor(.orange)
                .font(.system(size: 8, weight: .medium))
                .frame(width: 14, height: 14)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.15))
                        .blur(radius: 1)
                )
        }
        
        private var contextMenuContent: some View {
            Group {
                if isSubscribed {
                    Button {
                        Haptics.generateIfEnabled(.light)
                        subscriptionManager.unsubscribeFromSchedule(subscription.id)
                    } label: {
                        Label("取消订阅", systemImage: "bell.slash")
                    }
                } else {
                    Button {
                        Haptics.generateIfEnabled(.light)
                        Task {
                            await subscriptionManager.subscribeToSchedule(subscription)
                        }
                    } label: {
                        Label("订阅提醒", systemImage: "bell")
                    }
                }
                
                Button {
                    // 可以添加更多功能，比如查看详情
                } label: {
                    Label("查看详情", systemImage: "info.circle")
                }
            }
        }
    }

}
