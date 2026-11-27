import Foundation
import SplatDatabase
import GRDB

/// 对战列表：在通用分页视图模型之上提供对战数据源与批量操作。
@MainActor
final class BattleListViewModel: PagedRecordListViewModel<BattleListRowInfo, BattleGroupStatus> {
    static let shared = BattleListViewModel()

    private init() {
        super.init(kind: .battle, navigationTitle: "全部对战")
    }

    /// 重新加载对战列表（保留给视图层调用的语义化入口）。
    func loadBattles(limit: Int = 50, offset: Int = 0) async {
        syncNavigationTitle()
        await reload(limit: limit, offset: offset)
    }

    /// 从底部 Dock 选择对战模式（仅修改 `filter.modes`，保留收藏与可见性等其余筛选条件）。
    func selectModeFromDock(_ mode: BattleMode) async {
        filter.modes.removeAll()
        if mode != .all {
            filter.modes.insert(mode.rawValue)
        }
        syncNavigationTitle()
        await reload()
    }

    /// 根据当前 `filter.modes` 同步顶部导航标题，保证 Dock 与筛选页双向一致。
    func syncNavigationTitle() {
        if filter.modes.isEmpty {
            navigationTitle = BattleMode.all.name
        } else if filter.modes.count == 1,
                  let raw = filter.modes.first,
                  let mode = BattleMode(rawValue: raw) {
            navigationTitle = mode.name
        } else {
            navigationTitle = "对战 (\(filter.modes.count)种模式)"
        }
    }

    /// 除模式之外已启用的更多筛选条件数量（记录范围 / 只显示收藏）。
    var extraActiveFilterCount: Int {
        var count = 0
        if filter.visibility != .active { count += 1 }
        if filter.showOnlyFavorites { count += 1 }
        return count
    }

    /// 当前是否存在任何生效中的对战筛选条件。
    var hasAnyActiveFilter: Bool {
        !filter.modes.isEmpty || extraActiveFilterCount > 0
    }

    func fetchBattles() async {
        guard AppState.shared.isLogin else { return }
        await SN3Client.shared.fetchBattles()
    }

    // MARK: - PagedRecordListViewModel

    override func fetchPage(filter: Filter, limit: Int, offset: Int) async -> [BattleListRowInfo] {
        await measureTime(title: "loadBattles") {
            await BattleListRowInfo.battles(filter: filter, limit: limit, offset)
        }
    }

    override func fetchCard(groupId: Int64, accountId: Int) async throws -> BattleGroupStatus? {
        try await SplatDatabase.shared.dbQueue.read { db -> BattleGroupStatus? in
            try BattleGroupStatus.create(from: db, identifier: (Int(groupId), accountId))
        }
    }

    override func fetchCards(accountId: Int, offset: Int) async throws -> [BattleGroupStatus] {
        try await SplatDatabase.shared.dbQueue.read { db -> [BattleGroupStatus] in
            try BattleGroupStatus.create(from: db, identifier: (accountId, offset))
        }
    }
}
