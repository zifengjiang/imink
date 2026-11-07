import SwiftUI
import SplatDatabase

struct CoopPlayerStatusView:View {
    let status: CoopPlayerStatus?
    let onViewPlayerRecords: ((String, String, String) -> Void)?
    
    @State private var totalPlayCount: Int = 0
    @State private var isLoadingCount: Bool = false

    var body: some View {
        VStack{
            if let status = status {
                NameplateView(status: status)
                if let uniformName = status.uniformName{
                    Image(uniformName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                }
                HStack{
                    HStack(spacing: 3){
                        Image(.salmonRun)
                            .resizable()
                            .bold()
                            .foregroundStyle(Color.green)
                            .frame(width: 18,height: 18)
                        Text("\(status.defeatEnemyCount, places: 1)")
                            .font(.splatoonFont(size: 18))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                    }
//                    .frame(width: 45, alignment: .leading)

                    HStack(spacing: 3){
                        Image(.golden)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("\(status.goldenDeliverCount, places:1)")
                            .font(.splatoonFont(size: 18)) + 
                        Text("<\(status.goldenAssistCount, places:1)>")
                            .font(.splatoonFont(size: 13)).foregroundColor(.secondary)
                            
                    }

                    HStack(spacing: 3){
                        Image(.jobShiftCardHelp)
                            .resizable()
                            .bold()
                            .foregroundStyle(Color.green)
                            .frame(width: 18,height: 18)
                        Text("\(status.rescueCount, places: 1)")
                            .font(.splatoonFont(size: 18))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                    }
                    .frame(width: 45, alignment: .leading)

                    HStack(spacing: 3){
                        Image(.jobShiftCardDead)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("\(status.rescuedCount, places:1)")
                            .font(.splatoonFont(size: 18))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                    }
                }
                
                // 显示与这个玩家的游戏次数
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        Text("一起打工次数:")
                            .font(.splatoonFont(size: 12))
                            .foregroundColor(.secondary)
                        
                        if isLoadingCount {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("\(totalPlayCount)")
                                .font(.splatoonFont(size: 14))
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    // 如果总次数与当前shift中的次数不一致，显示说明
                    if totalPlayCount != status.count && totalPlayCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            Text("在其他时段也遇到过该玩家")
                                .font(.splatoonFont(size: 11))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.top, 8)
                
                // 添加查看玩家记录按钮
                if let onViewPlayerRecords = onViewPlayerRecords {
                    Button {
                        onViewPlayerRecords(status.name, status.byname, status.nameId)
                    } label: {
                        HStack {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 14))
                            Text("查看该玩家的所有记录")
                                .font(.splatoonFont(size: 14))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.top, 8)
                }
            } else {
                Text("无玩家数据")
                    .font(.splatoonFont(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 280, height: onViewPlayerRecords != nil ? 350 : 310)
        .padding(.all)
        .textureBackground(texture: .bubble, radius: 18)
        .onAppear {
            if let status = status {
                loadPlayCount(playerName: status.name, playerNameId: status.nameId)
            }
        }
    }
    
    private func loadPlayCount(playerName: String, playerNameId: String) {
        isLoadingCount = true
        Task {
            do {
                let count = try await SplatDatabase.shared.dbQueue.read { db in
                    try Int.fetchOne(db, sql: """
                        SELECT COUNT(DISTINCT c.id)
                        FROM coop_view c
                        JOIN coopPlayerResult cpr1 ON cpr1.coopId = c.id
                        JOIN coopPlayerResult cpr2 ON cpr2.coopId = c.id
                        JOIN player p1 ON p1.coopPlayerResultId = cpr1.id
                        JOIN player p2 ON p2.coopPlayerResultId = cpr2.id
                        WHERE c.accountId = ?
                        AND p2.name = ? AND p2.nameId = ?
                    """, arguments: [AppUserDefaults.shared.accountId, playerName, playerNameId]) ?? 0
                }
                
                await MainActor.run {
                    self.totalPlayCount = count
                    self.isLoadingCount = false
                }
            } catch {
                await MainActor.run {
                    self.totalPlayCount = 0
                    self.isLoadingCount = false
                }
            }
        }
    }
}

struct PlayerEncounterIndicator: View {
    let playerStatus: CoopPlayerStatus
    @State private var totalPlayCount: Int = 0
    @State private var isLoaded: Bool = false
    
    var body: some View {
        Group {
            Text("x\(playerStatus.count)")
                .foregroundColor(isLoaded && totalPlayCount > playerStatus.count ? .spGreen : .primary)
                .font(.splatoonFont(size: 15))
        }
        .onAppear {
            loadPlayCount()
        }
    }
    
    private func loadPlayCount() {
        Task { @MainActor in
            defer { isLoaded = true }

            do {
                totalPlayCount = try await CoopRepository.playCount(
                    withPlayerName: playerStatus.name,
                    nameId: playerStatus.nameId,
                    accountId: AppUserDefaults.shared.accountId
                )
            } catch {
                logError(error)
                totalPlayCount = 0
            }
        }
    }
}
