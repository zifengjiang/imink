import SwiftUI
import SplatDatabase

struct StagePreviewView: View {
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
            
            if homeViewModel.isLoadingStageRecords {
                // 加载状态
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在获取场地数据...")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 100)
            } else if let stageRecord = homeViewModel.getStageRecord(for: stageId) {
                // 显示场地记录数据
                StageStatsView(stageRecord: stageRecord)
            } else {
                // 无数据状态
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("暂无该场地的游戏记录")
                        .font(.splatoonFont(size: 14))
                        .foregroundStyle(.secondary)
                    Text("开始游戏后将显示详细数据")
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
            await homeViewModel.ensureStageRecordsAvailable()
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
        let scheduleGroups = homeViewModel.scheduleGroups
            var allSchedules: [Schedule] = []
            for schedules in scheduleGroups.values {
                allSchedules.append(contentsOf: schedules)
            }
            
            availableSchedules = allSchedules.filter { schedule in
                schedule._stage.contains { $0.nameId == stageId }
            }
        
    }
}

struct StageStatsView: View {
    let stageRecord: StageRecord
    
    var body: some View {
        VStack(spacing: 12) {
            // 最后游玩时间
            if let lastPlayedTime = stageRecord.stats?.lastPlayedTime {
                HStack {
                    Text("上次游玩:")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lastPlayedTime.toPlayedTimeString(full: true))
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.primary)
                }
            }
            
            // 胜率统计
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .center,spacing: 8) {
                if let winRateTw = stageRecord.stats?.winRateTw {
                    StatItemView(title: "占地对战", winRate: winRateTw, color: .spGreen)
                }
                
                if let winRateAr = stageRecord.stats?.winRateAr {
                    StatItemView(title: "真格区域", winRate: winRateAr, color: .spOrange)
                }
                
                if let winRateLf = stageRecord.stats?.winRateLf {
                    StatItemView(title: "真格塔楼", winRate: winRateLf, color: .spOrange)
                }
                
                if let winRateGl = stageRecord.stats?.winRateGl {
                    StatItemView(title: "真格鱼虎", winRate: winRateGl, color: .spPurple)
                }
                
                if let winRateCl = stageRecord.stats?.winRateCl {
                    StatItemView(title: "真格蛤蜊", winRate: winRateCl, color: .spRed)
                }
            }
        }
    }
}

struct StatItemView: View {
    let title: String
    let winRate: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.splatoonFont(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            Text("\(winRate * 100, specifier: "%.1f")%")
                .font(.splatoonFont(size: 14))
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// 订阅信息行视图


#Preview {
    StagePreviewView(stageId: "VnNTdGFnZS0x", stageName: "Vss_Scorch_Gorge")
        .fixSafeareaBackground()
}
