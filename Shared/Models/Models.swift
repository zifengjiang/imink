import Foundation
import SplatDatabase

struct RecordSelection<ID: Hashable> {
    private(set) var selectedIds: Set<ID> = []
    private(set) var isActive = false

    var selectedCount: Int {
        selectedIds.count
    }

    mutating func start() {
        isActive = true
    }

    mutating func cancel() {
        isActive = false
        selectedIds.removeAll()
    }

    mutating func toggle(_ id: ID) {
        start()
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    mutating func toggleAll(_ ids: [ID]) {
        start()
        let visibleIds = Set(ids)
        if selectedIds == visibleIds {
            selectedIds.removeAll()
        } else {
            selectedIds = visibleIds
        }
    }

    func contains(_ id: ID) -> Bool {
        selectedIds.contains(id)
    }
}


extension Coop {
    var gradeName: String?{
        if let afterGrade = afterGrade {
            return "CoopGrade-\(afterGrade)".base64EncodedString
        }
        return nil
    }

    var clear:Bool{
        wave == 3 && rule != "TEAM_CONTEST" || wave == 5 && rule == "TEAM_CONTEST"
    }
    
    // 软删除和喜爱功能扩展
    func toggleFavorite() throws {
        if isFavorite {
            try SplatDatabase.shared.unmarkCoopAsFavorite(coopId: id ?? 0)
        } else {
            try SplatDatabase.shared.markCoopAsFavorite(coopId: id ?? 0)
        }
    }
    
    func softDelete() throws {
        try SplatDatabase.shared.softDeleteCoop(coopId: id ?? 0)
    }
    
    func restore() throws {
        try SplatDatabase.shared.restoreCoop(coopId: id ?? 0)
    }
}

extension Battle {
    // 软删除和喜爱功能扩展
    func toggleFavorite() throws {
        if isFavorite {
            try SplatDatabase.shared.unmarkBattleAsFavorite(battleId: id ?? 0)
        } else {
            try SplatDatabase.shared.markBattleAsFavorite(battleId: id ?? 0)
        }
    }
    
    func softDelete() throws {
        try SplatDatabase.shared.softDeleteBattle(battleId: id ?? 0)
    }
    
    func restore() throws {
        try SplatDatabase.shared.restoreBattle(battleId: id ?? 0)
    }
}
