import SwiftUI
import SplatDatabase

struct BattleBatchOperationView: View {
    @Binding var selectedBattles: Set<Int64>
    @Binding var isSelectionMode: Bool
    let battles: [BattleListRowInfo]
    
    var body: some View {
        if isSelectionMode {
            VStack {
                HStack {
                    Button("全选") {
                        if selectedBattles.count == battles.count {
                            selectedBattles.removeAll()
                        } else {
                            selectedBattles = Set(battles.map { $0.id })
                        }
                    }
                    
                    Spacer()
                    
                    Text("已选择 \(selectedBattles.count) 项")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("取消") {
                        isSelectionMode = false
                        selectedBattles.removeAll()
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("批量收藏") {
                        batchToggleFavorite()
                    }
                    .disabled(selectedBattles.isEmpty)
                    
                    Button("批量删除") {
                        batchDelete()
                    }
                    .foregroundColor(.red)
                    .disabled(selectedBattles.isEmpty)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemGray6))
        }
    }
    
    private func batchToggleFavorite() {
        Task {
            do {
                for battleId in selectedBattles {
                    if let actualBattle = try await SplatDatabase.shared.dbQueue.read({ db in
                        try Battle.fetchOne(db, key: battleId)
                    }) {
                        try actualBattle.toggleFavorite()
                    }
                }
                
                NotificationCenter.default.post(name: .battleDataChanged, object: nil)
                isSelectionMode = false
                selectedBattles.removeAll()
            } catch {
                print("Error batch toggling favorites: \(error)")
            }
        }
    }
    
    private func batchDelete() {
        let indicatorId = UUID().uuidString
        let totalCount = selectedBattles.count
        
        Task {
            do {
                // 显示进度提示
                await MainActor.run {
                    Indicators.shared.display(.init(
                        id: indicatorId,
                        icon: .progressIndicator,
                        title: "正在删除",
                        subtitle: "0/\(totalCount)",
                        dismissType: .manual,
                        isUserDismissible: false
                    ))
                }
                
                // 批量处理，减少数据库操作次数
                let battleIds = Array(selectedBattles)
                let batchSize = 50 // 每批处理50个
                var processedCount = 0
                
                for i in stride(from: 0, to: battleIds.count, by: batchSize) {
                    let endIndex = min(i + batchSize, battleIds.count)
                    let batch = Array(battleIds[i..<endIndex])
                    
                    // 批量软删除 - 直接在事务内执行SQL更新
                    try await SplatDatabase.shared.dbQueue.write { db in
                        for battleId in batch {
                            try db.execute(sql: "UPDATE battle SET isDeleted = 1 WHERE id = ?", arguments: [battleId])
                        }
                    }
                    
                    processedCount += batch.count
                    
                    // 更新进度
                    await MainActor.run {
                        Indicators.shared.updateSubtitle(for: indicatorId, subtitle: "\(processedCount)/\(totalCount)")
                    }
                    
                    // 让出控制权，避免阻塞UI
                    await Task.yield()
                }
                
                await MainActor.run {
                    // 显示完成提示
                    Indicators.shared.dismiss(with: indicatorId)
                    Indicators.shared.display(.init(
                        id: UUID().uuidString,
                        icon: .systemImage("checkmark.circle.fill"),
                        title: "删除完成",
                        subtitle: "已删除 \(totalCount) 条记录",
                        dismissType: .after(2)
                    ))
                    
                    NotificationCenter.default.post(name: .battleDataChanged, object: nil)
                    isSelectionMode = false
                    selectedBattles.removeAll()
                }
            } catch {
                await MainActor.run {
                    Indicators.shared.dismiss(with: indicatorId)
                    Indicators.shared.display(.init(
                        id: UUID().uuidString,
                        icon: .systemImage("xmark.circle.fill"),
                        title: "删除失败",
                        subtitle: error.localizedDescription,
                        dismissType: .after(3),
                        style: .error
                    ))
                }
                print("Error batch deleting battles: \(error)")
            }
        }
    }
}
