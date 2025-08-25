import Foundation
import SplatDatabase


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

