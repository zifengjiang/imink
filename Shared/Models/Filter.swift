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
    
    // 玩家筛选选项
    var playerName: String? = nil  // 筛选特定玩家名称
    var playerByname: String? = nil  // 筛选特定玩家昵称
    var playerNameId: String? = nil  // 筛选特定玩家ID
    
    mutating func clear() {
        self.modes.removeAll()
        self.rules.removeAll()
        self.stageIds.removeAll()
        self.weaponIds.removeAll()
        self.start = getCoopEarliestPlayedTime()
        self.end = Date()
        self.showDeleted = false
        self.showOnlyFavorites = false
        self.showOnlyActive = true
        self.playerName = nil
        self.playerByname = nil
        self.playerNameId = nil
    }
}
