import SwiftUI
import SplatDatabase

struct CoopBatchOperationView: View {
    @Binding var selectedCoops: Set<Int64>
    @Binding var isSelectionMode: Bool
    let coops: [CoopListRowInfo]
    
    var body: some View {
        if isSelectionMode {
            VStack {
                HStack {
                    Button("全选") {
                        if selectedCoops.count == coops.count {
                            selectedCoops.removeAll()
                        } else {
                            selectedCoops = Set(coops.map { $0.id })
                        }
                    }
                    
                    Spacer()
                    
                    Text("已选择 \(selectedCoops.count) 项")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("取消") {
                        isSelectionMode = false
                        selectedCoops.removeAll()
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("批量收藏") {
                        batchToggleFavorite()
                    }
                    .disabled(selectedCoops.isEmpty)
                    
                    Button("批量删除") {
                        batchDelete()
                    }
                    .foregroundColor(.red)
                    .disabled(selectedCoops.isEmpty)
                    
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
                for coopId in selectedCoops {
                    if let actualCoop = try await SplatDatabase.shared.dbQueue.read({ db in
                        try Coop.fetchOne(db, key: coopId)
                    }) {
                        try actualCoop.toggleFavorite()
                    }
                }
                
                NotificationCenter.default.post(name: .coopDataChanged, object: nil)
                isSelectionMode = false
                selectedCoops.removeAll()
            } catch {
                print("Error batch toggling favorites: \(error)")
            }
        }
    }
    
    private func batchDelete() {
        Task {
            do {
                for coopId in selectedCoops {
                    if let actualCoop = try await SplatDatabase.shared.dbQueue.read({ db in
                        try Coop.fetchOne(db, key: coopId)
                    }) {
                        try actualCoop.softDelete()
                    }
                }
                
                NotificationCenter.default.post(name: .coopDataChanged, object: nil)
                isSelectionMode = false
                selectedCoops.removeAll()
            } catch {
                print("Error batch deleting coops: \(error)")
            }
        }
    }
}
