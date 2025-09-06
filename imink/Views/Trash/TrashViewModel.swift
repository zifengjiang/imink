import Foundation
import Combine
import SplatDatabase
import SwiftUI

enum TrashDataType {
    case coop
    case battle
}

@MainActor
class TrashViewModel: ObservableObject {
    @Published var deletedCoops: [Coop] = []
    @Published var deletedBattles: [Battle] = []
    @Published var showPermanentDeleteAlert = false
    
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        // 监听数据变化通知
        NotificationCenter.default.publisher(for: .coopDataChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadDeletedCoops()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .battleDataChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadDeletedBattles()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadData() async {
        await loadDeletedCoops()
        await loadDeletedBattles()
    }
    
    func refresh() async {
        await loadData()
    }
    
    private func loadDeletedCoops() async {
        do {
            let coops = try await SplatDatabase.shared.fetchDeletedCoops()
            self.deletedCoops = coops
        } catch {
            print("Error loading deleted coops: \(error)")
            self.deletedCoops = []
        }
    }
    
    private func loadDeletedBattles() async {
        do {
            let battles = try await SplatDatabase.shared.fetchDeletedBattles()
            self.deletedBattles = battles
        } catch {
            print("Error loading deleted battles: \(error)")
            self.deletedBattles = []
        }
    }
    
    func restoreAll(type: TrashDataType) async {
        let indicatorId = UUID().uuidString
        
        do {
            let totalCount: Int
            let items: [Any]
            
            switch type {
            case .coop:
                totalCount = deletedCoops.count
                items = deletedCoops
            case .battle:
                totalCount = deletedBattles.count
                items = deletedBattles
            }
            
            guard totalCount > 0 else { return }
            
            // 显示进度提示
            Indicators.shared.display(.init(
                id: indicatorId,
                icon: .progressIndicator,
                title: "正在恢复",
                subtitle: "0/\(totalCount)",
                dismissType: .manual,
                isUserDismissible: false
            ))
            
            let batchSize = 50 // 每批处理50个
            var processedCount = 0
            
            switch type {
            case .coop:
                let coops = deletedCoops
                for i in stride(from: 0, to: coops.count, by: batchSize) {
                    let endIndex = min(i + batchSize, coops.count)
                    let batch = Array(coops[i..<endIndex])
                    
                    // 批量恢复 - 直接在事务内执行SQL更新
                    try await SplatDatabase.shared.dbQueue.write { db in
                        for coop in batch {
                            try db.execute(sql: "UPDATE coop SET isDeleted = 0 WHERE id = ?", arguments: [coop.id ?? 0])
                        }
                    }
                    
                    processedCount += batch.count
                    
                    // 更新进度
                    Indicators.shared.updateSubtitle(for: indicatorId, subtitle: "\(processedCount)/\(totalCount)")
                    
                    // 让出控制权，避免阻塞UI
                    await Task.yield()
                }
                NotificationCenter.default.post(name: .coopDataChanged, object: nil)
                
            case .battle:
                let battles = deletedBattles
                for i in stride(from: 0, to: battles.count, by: batchSize) {
                    let endIndex = min(i + batchSize, battles.count)
                    let batch = Array(battles[i..<endIndex])
                    
                    // 批量恢复 - 直接在事务内执行SQL更新
                    try await SplatDatabase.shared.dbQueue.write { db in
                        for battle in batch {
                            try db.execute(sql: "UPDATE battle SET isDeleted = 0 WHERE id = ?", arguments: [battle.id ?? 0])
                        }
                    }
                    
                    processedCount += batch.count
                    
                    // 更新进度
                    Indicators.shared.updateSubtitle(for: indicatorId, subtitle: "\(processedCount)/\(totalCount)")
                    
                    // 让出控制权，避免阻塞UI
                    await Task.yield()
                }
                NotificationCenter.default.post(name: .battleDataChanged, object: nil)
            }
            
            // 显示完成提示
            Indicators.shared.dismiss(with: indicatorId)
            Indicators.shared.display(.init(
                id: UUID().uuidString,
                icon: .systemImage("checkmark.circle.fill"),
                title: "恢复完成",
                subtitle: "已恢复 \(totalCount) 条记录",
                dismissType: .after(2)
            ))
            
            await loadData()
        } catch {
            Indicators.shared.dismiss(with: indicatorId)
            Indicators.shared.display(.init(
                id: UUID().uuidString,
                icon: .systemImage("xmark.circle.fill"),
                title: "恢复失败",
                subtitle: error.localizedDescription,
                dismissType: .after(3),
                style: .error
            ))
            print("Error restoring all: \(error)")
        }
    }
    
    func permanentDeleteAll(type: TrashDataType) async {
        do {
            switch type {
            case .coop:
                try SplatDatabase.shared.permanentlyDeleteSoftDeletedCoops()
                NotificationCenter.default.post(name: .coopDataChanged, object: nil)
            case .battle:
                try SplatDatabase.shared.permanentlyDeleteSoftDeletedBattles()
                NotificationCenter.default.post(name: .battleDataChanged, object: nil)
            }
            await loadData()
        } catch {
            print("Error permanently deleting all: \(error)")
        }
    }
}
