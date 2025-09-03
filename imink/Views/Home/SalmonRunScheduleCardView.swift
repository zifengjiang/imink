import SwiftUI
import SplatDatabase

struct SalmonRunScheduleCardView: View {
    let schedule: Schedule
    @EnvironmentObject private var subscriptionManager: ScheduleSubscriptionManager
    
    // 添加弹窗状态管理
    @Binding var showCoopStagePreview: Bool
    @Binding var activeCoopStage: ImageMap?
    @Binding var hoveredCoopStage: Bool
    
    private var subscription: ScheduleSubscription {
        subscriptionManager.createSubscription(from: schedule)
    }
    
    private var isSubscribed: Bool {
        subscriptionManager.isSubscribed(subscription.id)
    }

    var body: some View {
        ZStack {
            VStack{
                VStack{
                    Text(schedule.formattedSalmonRunTime)
                        .font(.splatoonFont(size: 15))
                        .colorInvert()
                }
                .padding(3)
                .padding(.horizontal)
                .background(Color.secondary)
                .clipShape(Capsule())
                .padding(.bottom, 5)

                HStack{
                    if schedule._stage.count >= 1{
                        VStack{
                            Text(schedule._stage[0].nameId.localizedFromSplatNet)
                                .font(.splatoonFont(size: 15))
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)

                            Image(schedule._stage[0].name)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .onTapGesture {
                                    activeCoopStage = schedule._stage[0]
                                    showCoopStagePreview = true
                                }
                        }
                    }
                    VStack(spacing: 8){
                        HStack{
                            schedule.rule1.icon
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30, alignment: .center)

                            Text(schedule.rule1.localized)
                                .font(.splatoonFont(size: 20))
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                        }

                        HStack{

                            if let _boss = schedule._boss, schedule.rule1 != .teamContest{
                                Image(_boss.name)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)

                                Text(_boss.nameId.localizedFromSplatNet)
                                    .font(.splatoonFont(size: 15))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.3)
                            }
                        }

                        HStack{

                            ForEach(schedule._weapons.indices, id: \.self){ index in
                                Image(schedule._weapons[index].name)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                            }

                        }
                    }
                }

            }
            
            // 订阅状态指示器
            if isSubscribed {
                VStack {
                    HStack {
                        Spacer()
                        subscriptionIndicator
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.listItemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contextMenu {
            contextMenuContent
        }
    }
    
    private var subscriptionIndicator: some View {
        Image(systemName: "bell.fill")
            .foregroundColor(.orange)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.1))
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

    //#Preview {
    //    SalmonRunScheduleCardView()
    //}
