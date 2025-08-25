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
        Task {
            do {
                for battleId in selectedBattles {
                    if let actualBattle = try await SplatDatabase.shared.dbQueue.read({ db in
                        try Battle.fetchOne(db, key: battleId)
                    }) {
                        try actualBattle.softDelete()
                    }
                }
                
                NotificationCenter.default.post(name: .battleDataChanged, object: nil)
                isSelectionMode = false
                selectedBattles.removeAll()
            } catch {
                print("Error batch deleting battles: \(error)")
            }
        }
    }
}
