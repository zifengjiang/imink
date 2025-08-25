import Foundation
import GRDB
import SplatDatabase

func getCoopEarliestPlayedTime() -> Date{
    try! SplatDatabase.shared.dbQueue.read { db in
        try Date.fetchOne(db, sql: "SELECT MIN(playedTime) FROM coop") ?? Date(timeIntervalSince1970: 0)
    }
}

struct Filter {
    var modes: Set<String> = []
    var rules: Set<String> = []
    var stageIds: Set<Int> = []
    var weaponIds: Set<Int> = []
    var start: Date = getCoopEarliestPlayedTime()
    var end: Date = Date()
    
    // 软删除和喜爱功能的过滤选项
    var showDeleted: Bool = false
    var showOnlyFavorites: Bool = false
    var showOnlyActive: Bool = true  // 默认只显示活跃（未删除）的记录
}
