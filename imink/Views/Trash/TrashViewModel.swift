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
        do {
            switch type {
            case .coop:
                for coop in deletedCoops {
                    try coop.restore()
                }
                NotificationCenter.default.post(name: .coopDataChanged, object: nil)
            case .battle:
                for battle in deletedBattles {
                    try battle.restore()
                }
                NotificationCenter.default.post(name: .battleDataChanged, object: nil)
            }
            await loadData()
        } catch {
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
