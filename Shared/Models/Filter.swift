import Foundation
import GRDB
import SplatDatabase

struct Filter {
    var modes: Set<String> = []
    var rules: Set<String> = []
    var stageIds: Set<Int> = []
    var weaponIds: Set<Int> = []
    var start: Date = CoopRepository.earliestPlayedTime()
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
        self.start = CoopRepository.earliestPlayedTime()
        self.end = Date()
        self.showDeleted = false
        self.showOnlyFavorites = false
        self.showOnlyActive = true
        self.playerName = nil
        self.playerByname = nil
        self.playerNameId = nil
    }
}

extension Filter {
    /// 「记录状态」筛选的三种模式。
    enum RecordVisibility: CaseIterable {
        case active
        case deleted
        case all

        var title: String {
            switch self {
            case .active: return "活跃记录"
            case .deleted: return "已删除"
            case .all: return "全部记录"
            }
        }
    }

    /// 由 `showDeleted` / `showOnlyActive` 推导出的记录状态模式。
    var visibility: RecordVisibility {
        get {
            guard showDeleted else { return .active }
            return showOnlyActive ? .all : .deleted
        }
        set {
            switch newValue {
            case .active:
                showOnlyActive = true
                showDeleted = false
            case .deleted:
                showOnlyActive = false
                showDeleted = true
            case .all:
                showOnlyActive = true
                showDeleted = true
            }
        }
    }
}
