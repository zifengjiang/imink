import SwiftUI
import SplatDatabase

struct SubscriptionOptionsSheet: View {
    let stageId: String
    let stageName: String
    let schedules: [Schedule]
    
    @EnvironmentObject private var subscriptionManager: ScheduleSubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 头部信息
                VStack(spacing: 12) {
                    Image(stageName)
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                    
                    Text(stageId.localizedFromSplatNet)
                        .font(.splatoonFont(size: 16))
                        .multilineTextAlignment(.center)
                    
                    Text("选择要订阅的日程")
                        .font(.splatoonFont(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding()
                
                Divider()
                
                // 日程列表
                if schedules.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("暂无该场地的日程安排")
                            .font(.splatoonFont(size: 16))
                            .foregroundStyle(.secondary)
                        Text("请稍后再试")
                            .font(.splatoonFont(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(schedules, id: \.id) { schedule in
                            ScheduleSubscriptionRow(
                                schedule: schedule,
                                stageId: stageId
                            )
                            .environmentObject(subscriptionManager)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("订阅管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct ScheduleSubscriptionRow: View {
    let schedule: Schedule
    let stageId: String
    
    @EnvironmentObject private var subscriptionManager: ScheduleSubscriptionManager
    
    private var subscription: ScheduleSubscription {
        if schedule.mode == .fest || schedule.mode == .bankara {
            // 对于bankara和fest模式，需要检查具体使用哪个规则和场地
            if schedule.challengeStage.contains(where: { $0.nameId == stageId }) {
                return subscriptionManager.createSubscription(from: schedule, specificRule: schedule.rule1, stages: schedule.challengeStage, isOpen: false)
            } else if schedule.openStage.contains(where: { $0.nameId == stageId }) {
                return subscriptionManager.createSubscription(from: schedule, specificRule: schedule.rule2!, stages: schedule.openStage, isOpen: true)
            }
        }
        return subscriptionManager.createSubscription(from: schedule)
    }
    
    private var isSubscribed: Bool {
        subscriptionManager.isSubscribed(subscription.id)
    }
    
    private var scheduleTitle: String {
        if schedule.mode == .salmonRun {
            return "鲑鱼跑 - \(schedule.rule1.localizedDescription)"
        } else {
            let modeText = schedule.mode.localizedDescription
            let ruleText = schedule.rule1.localizedDescription
            return "\(modeText) - \(ruleText)"
        }
    }
    
    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: schedule.startTime)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 日程图标
            VStack(spacing: 4) {
                if schedule.mode == .fest {
                    FestIcon()
                        .frame(width: 20, height: 20)
                } else {
                    schedule.mode.icon
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
                
                if schedule.mode == .bankara || schedule.mode == .x || schedule.mode == .event {
                    schedule.rule1.icon
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }
            }
            
            // 日程信息
            VStack(alignment: .leading, spacing: 4) {
                Text(scheduleTitle)
                    .font(.splatoonFont(size: 14))
                    .lineLimit(2)
                
                Text(timeText)
                    .font(.splatoonFont(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 订阅按钮
            Button(action: {
                Haptics.generateIfEnabled(.light)
                if isSubscribed {
                    subscriptionManager.unsubscribeFromSchedule(subscription.id)
                } else {
                    Task {
                        await subscriptionManager.subscribeToSchedule(subscription)
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isSubscribed ? "bell.fill" : "bell")
                        .font(.system(size: 12))
                    Text(isSubscribed ? "已订阅" : "订阅")
                        .font(.splatoonFont(size: 12))
                }
                .foregroundColor(isSubscribed ? .white : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSubscribed ? Color.orange : Color.orange.opacity(0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SubscriptionOptionsSheet(
        stageId: "VnNTdGFnZS0x",
        stageName: "Vss_Scorch_Gorge",
        schedules: []
    )
    .environmentObject(ScheduleSubscriptionManager.shared)
}
