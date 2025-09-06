import SwiftUI
import SplatDatabase
import GRDB

struct CoopPlayerView: View {
    let result: CoopPlayerResult?
    var onViewPlayerRecords: ((String, String, String) -> Void)? = nil
    @State private var playCount: Int = 0
    @State private var isLoadingCount: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            if let result = result, let player = result.player {
                NameplateView(result: result)
                    .frame(height: 60)
                
                if let uniformName = player.uniformName {
                    Image(uniformName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                }
                
                // 显示与这个玩家的游戏次数
                if player.isMyself != true {
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
                                Text("\(playCount)")
                                    .font(.splatoonFont(size: 14))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        // 查看记录按钮
                        if let onViewPlayerRecords = onViewPlayerRecords {
                            Button(action: {
                                onViewPlayerRecords(player.name, player.byname, player.nameId)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .foregroundColor(.accentColor)
                                    Text("查看打工记录")
                                        .font(.splatoonFont(size: 14))
                                        .foregroundColor(.accentColor)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
//                VStack(spacing: 8) {
//                    HStack(spacing: 15) {
//                        VStack(spacing: 4) {
//                            Image(.golden)
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                            Text("\(result.goldenDeliverCount)")
//                                .font(.splatoonFont(size: 16))
//                            Text("金蛋")
//                                .font(.splatoonFont(size: 12))
//                                .foregroundStyle(.secondary)
//                        }
//                        
//                        VStack(spacing: 4) {
//                            Image(.egg)
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                            Text("\(result.deliverCount)")
//                                .font(.splatoonFont(size: 16))
//                            Text("普通蛋")
//                                .font(.splatoonFont(size: 12))
//                                .foregroundStyle(.secondary)
//                        }
//                        
//                        VStack(spacing: 4) {
//                            Image(player.species ? .rescueINKLING : .rescueOCTOLING)
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                            Text("\(result.rescueCount)")
//                                .font(.splatoonFont(size: 16))
//                            Text("救援")
//                                .font(.splatoonFont(size: 12))
//                                .foregroundStyle(.secondary)
//                        }
//                    }
//                    
//                    HStack(spacing: 15) {
//                        VStack(spacing: 4) {
//                            Image(.salmonRun)
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                            Text("\(result.defeatEnemyCount)")
//                                .font(.splatoonFont(size: 16))
//                            Text("击败敌人")
//                                .font(.splatoonFont(size: 12))
//                                .foregroundStyle(.secondary)
//                        }
//                        
//                        if let specialWeaponName = result.specialWeaponName {
//                            VStack(spacing: 4) {
//                                SpecialWeaponImage(imageName: specialWeaponName, size: 20)
//                                Text("特殊武器")
//                                    .font(.splatoonFont(size: 12))
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
//                    }
//                }
            }
        }
//        .frame(width: 250, height: 300)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            if let player = result?.player, player.isMyself != true {
                loadPlayCount(player: player)
            }
        }
    }
    
    private func loadPlayCount(player: Player) {
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
                    """, arguments: [AppUserDefaults.shared.accountId, player.name, player.nameId]) ?? 0
                }
                
                await MainActor.run {
                    self.playCount = count
                    self.isLoadingCount = false
                }
            } catch {
                await MainActor.run {
                    self.playCount = 0
                    self.isLoadingCount = false
                }
            }
        }
    }
}

#Preview {
    CoopPlayerView(result: nil)
}
