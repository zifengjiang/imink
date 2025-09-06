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
        let indicatorId = UUID().uuidString
        let totalCount = selectedCoops.count
        
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
                let coopIds = Array(selectedCoops)
                let batchSize = 50 // 每批处理50个
                var processedCount = 0
                
                for i in stride(from: 0, to: coopIds.count, by: batchSize) {
                    let endIndex = min(i + batchSize, coopIds.count)
                    let batch = Array(coopIds[i..<endIndex])
                    
                    // 批量软删除 - 直接在事务内执行SQL更新
                    try await SplatDatabase.shared.dbQueue.write { db in
                        for coopId in batch {
                            try db.execute(sql: "UPDATE coop SET isDeleted = 1 WHERE id = ?", arguments: [coopId])
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
                    
                    NotificationCenter.default.post(name: .coopDataChanged, object: nil)
                    isSelectionMode = false
                    selectedCoops.removeAll()
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
                print("Error batch deleting coops: \(error)")
            }
        }
    }
}
