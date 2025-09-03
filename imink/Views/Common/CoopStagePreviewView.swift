import SwiftUI
import SplatDatabase

struct CoopStagePreviewView: View {
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
        .padding(20)
        .frame(width: 280)
        .background(Color.listItemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8, x: 0, y: 4)
        .task {
            await homeViewModel.ensureCoopRecordAvailable()
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



#Preview {
    CoopStagePreviewView(stageId: "Q29vcFN0YWdlLTE=", stageName: "Coop_Spawning_Grounds")
        .fixSafeareaBackground()
}
