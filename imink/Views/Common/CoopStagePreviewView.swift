import SwiftUI
import SplatDatabase

struct CoopStagePreviewView: View {
    let stageId: String
    let stageName: String
    @ObservedObject private var homeViewModel = HomeViewModel.shared
    @EnvironmentObject private var subscriptionManager: ScheduleSubscriptionManager
    
    // 添加订阅相关的状态
    @State private var showSubscriptionOptions = false
    @State private var availableSchedules: [Schedule] = []
    
    var body: some View {
        VStack(spacing: 16) {
            // 场地图片和名称
            VStack(spacing: 8) {
                Image(stageName)
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.separator), lineWidth: 1)
                    )
                
                Text(stageId.localizedFromSplatNet)
                    .font(.splatoonFont(size: 18))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            // 订阅功能区域
            subscriptionSection
            
            if homeViewModel.isLoadingCoopRecord {
                // 加载状态
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在获取场地数据...")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 100)
            } else if let stageRecord = homeViewModel.getCoopStageRecord(for: stageId) {
                // 显示场地记录数据
                CoopStageStatsView(stageRecord: stageRecord)
            } else {
                // 无数据状态
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("暂无该场地的打工记录")
                        .font(.splatoonFont(size: 14))
                        .foregroundStyle(.secondary)
                    Text("开始打工后将显示详细数据")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 100)
            }
        }
        .padding(10)
        .frame(width: 320) // 增加宽度以容纳订阅功能
        .textureBackground(texture: .bubble, radius: 18)
        .shadow(radius: 8, x: 0, y: 4)
        .task {
            await homeViewModel.ensureCoopRecordAvailable()
            loadAvailableSchedules()
        }
        .sheet(isPresented: $showSubscriptionOptions) {
            SubscriptionOptionsSheet(
                stageId: stageId,
                stageName: stageName,
                schedules: availableSchedules
            )
            .environmentObject(subscriptionManager)
        }
    }
    
    // 订阅功能区域
    private var subscriptionSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "bell")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("订阅提醒")
                    .font(.splatoonFont(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            if availableSchedules.isEmpty {
                Text("暂无该场地的日程安排")
                    .font(.splatoonFont(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // 检查是否有订阅
                let stageSubscriptions = getStageSubscriptions()
                
                if stageSubscriptions.isEmpty {
                    // 没有订阅时显示订阅按钮
                    Button(action: {
                        showSubscriptionOptions = true
                        Haptics.generateIfEnabled(.light)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.badge.plus")
                                .font(.system(size: 14))
                            Text("订阅提醒")
                                .font(.splatoonFont(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // 有订阅时显示订阅信息
                    VStack(spacing: 8) {
                        // 订阅状态指示
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                            Text("已订阅 \(stageSubscriptions.count) 个日程")
                                .font(.splatoonFont(size: 12))
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                        
                        // 显示订阅的日程信息
                        ForEach(stageSubscriptions.prefix(2), id: \.id) { subscription in
                            SubscriptionInfoRow(subscription: subscription)
                        }
                        
                        // 如果订阅数量超过2个，显示更多提示
                        if stageSubscriptions.count > 2 {
                            Text("还有 \(stageSubscriptions.count - 2) 个订阅...")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        
                        // 管理订阅按钮
                        Button(action: {
                            showSubscriptionOptions = true
                            Haptics.generateIfEnabled(.light)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "gear")
                                    .font(.system(size: 12))
                                Text("管理订阅")
                                .font(.splatoonFont(size: 12))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // 获取该场地的订阅
    private func getStageSubscriptions() -> [ScheduleSubscription] {
        return subscriptionManager.subscriptions.filter { subscription in
            subscription.stages.contains { stageName in
                stageName == stageId.localizedFromSplatNet
            }
        }.sorted { $0.startTime < $1.startTime }
    }
    
    // 加载可用的日程
    private func loadAvailableSchedules() {
        // 从HomeViewModel获取包含该场地的日程
        let schedules = homeViewModel.salmonRunSchedules
            availableSchedules = schedules.filter { schedule in
                schedule._stage.contains { $0.nameId == stageId }
            }
        
    }
}

struct CoopStageStatsView: View {
    let stageRecord: StageHighestRecord
    
    var body: some View {
        VStack(spacing: 12) {
            // 最高评价标题
            HStack {
                Image(.salmonRun)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("最高评价记录")
                    .font(.splatoonFont(size: 16))
                    .foregroundStyle(.salmonRunTheme)
            }
            
            // 评价和分数
            VStack(spacing: 8) {
                HStack {
                    Text("评价等级:")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(stageRecord.grade.localizedFromSplatNet)
                        .font(.splatoonFont(size: 16))
                        .fontWeight(.medium)
                        .foregroundStyle(.waveClear)
                }
                
                HStack {
                    Text("评价分数:")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(stageRecord.gradePoint)")
                        .font(.splatoonFont(size: 16))
                        .fontWeight(.medium)
                        .foregroundStyle(.waveClear)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.waveClear.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // 提示文本
            Text("继续打工以提高评价等级!")
                .font(.splatoonFont(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// 订阅信息行视图


#Preview {
    CoopStagePreviewView(stageId: "Q29vcFN0YWdlLTE=", stageName: "Coop_Spawning_Grounds")
        .fixSafeareaBackground()
}
