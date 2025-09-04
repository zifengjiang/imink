import SwiftUI
import SplatDatabase

struct StagePreviewView: View {
    let stageId: String
    let stageName: String
    @ObservedObject private var homeViewModel = HomeViewModel.shared
    
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
        .frame(width: 280)
        .textureBackground(texture: .bubble, radius: 18)
        .shadow(radius: 8, x: 0, y: 4)
        .task {
            await homeViewModel.ensureStageRecordsAvailable()
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
                GridItem(.flexible())
            ], spacing: 8) {
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



#Preview {
    StagePreviewView(stageId: "VnNTdGFnZS0x", stageName: "Vss_Scorch_Gorge")
        .fixSafeareaBackground()
}
