import Foundation
import SplatDatabase
import GRDB
import Combine

/// 打工列表：在通用分页视图模型之上提供打工数据源、批量操作与详情页收藏态。
@MainActor
final class CoopListViewModel: PagedRecordListViewModel<CoopListRowInfo, CoopGroupStatus> {
    static let shared = CoopListViewModel()

    @Published var detailViewModel: CoopDetailViewModel?
    @Published var detailId: Int64?
    @Published var currentCoopIsFavorite = false
    @Published var isShowingShiftCards = false

    private init() {
        super.init(kind: .coop, navigationTitle: "全部打工")
    }

    /// 重新加载打工列表（保留给视图层调用的语义化入口）。
    func loadCoops(limit: Int = 50, offset: Int = 0, loadRecent: Bool = false) async {
        isShowingShiftCards = false
        if loadRecent {
            filter = Filter()
        }
        syncNavigationTitle()
        await reload(limit: limit, offset: offset)
    }

    /// 从底部 Dock 选择打工规则（仅修改 `filter.rules`，保留场地、武器、时段、工友等其余筛选条件）。
    func selectRuleFromDock(_ rule: CoopRule) async {
        isShowingShiftCards = false
        filter.rules.removeAll()
        if rule != .ALL {
            filter.rules.insert(rule.rawValue)
        }
        syncNavigationTitle()
        await reload()
    }

    /// 从底部 Dock 切换至「打工卡片」班次聚合视图。
    func selectShiftCardsFromDock() async {
        isShowingShiftCards = true
        filter.rules.removeAll()
        navigationTitle = "打工卡片"
        await loadCards()
    }

    /// 根据当前 `filter.rules` 与视图模式同步顶部导航标题。
    func syncNavigationTitle() {
        if isShowingShiftCards {
            navigationTitle = "打工卡片"
            return
        }
        if filter.rules.isEmpty {
            navigationTitle = CoopRule.ALL.name
        } else if filter.rules.count == 1,
                  let raw = filter.rules.first,
                  let rule = CoopRule(rawValue: raw) {
            navigationTitle = rule.name
        } else {
            navigationTitle = "打工 (\(filter.rules.count)种规则)"
        }
    }

    /// 除打工规则外已启用的更多筛选条件数量（时段 / 记录状态 / 收藏 / 地图 / 工友 / 武器）。
    var extraActiveFilterCount: Int {
        var count = 0
        if filter.visibility != .active { count += 1 }
        if filter.showOnlyFavorites { count += 1 }
        if !filter.stageIds.isEmpty { count += 1 }
        if !filter.weaponIds.isEmpty { count += 1 }
        if !(filter.playerName ?? "").isEmpty ||
            !(filter.playerByname ?? "").isEmpty ||
            !(filter.playerNameId ?? "").isEmpty {
            count += 1
        }
        let earliest = CoopRepository.earliestPlayedTime()
        if abs(filter.start.timeIntervalSince(earliest)) > 86_400 ||
            abs(Date().timeIntervalSince(filter.end)) > 86_400 {
            count += 1
        }
        return count
    }

    /// 当前是否存在任何生效中的打工筛选或卡片视图切换。
    var hasAnyActiveFilter: Bool {
        !filter.rules.isEmpty || isShowingShiftCards || extraActiveFilterCount > 0
    }

    func fetchCoops() async {
        guard AppState.shared.isLogin else { return }
        await SN3Client.shared.fetchCoops()
    }

    // MARK: - PagedRecordListViewModel

    override func fetchPage(filter: Filter, limit: Int, offset: Int) async -> [CoopListRowInfo] {
        await measureTime(title: "loadCoops") {
            await coops(filter: filter, limit: limit, offset)
        }
    }

    override func fetchCard(groupId: Int64, accountId: Int) async throws -> CoopGroupStatus? {
        try await SplatDatabase.shared.dbQueue.read { db -> CoopGroupStatus? in
            try CoopGroupStatus.create(from: db, identifier: (Int(groupId), accountId))
        }
    }

    override func fetchCards(accountId: Int, offset: Int) async throws -> [CoopGroupStatus] {
        try await SplatDatabase.shared.dbQueue.read { db -> [CoopGroupStatus] in
            try CoopGroupStatus.create(from: db, identifier: (accountId, offset))
        }
    }

    // MARK: - 详情页收藏态

    func toggleFavorite(for selectedRow: String?) async {
        guard let coop = detail(for: selectedRow) else { return }

        do {
            if let isFavorite = try await RecordStore.toggleCoopFavorite(coopId: coop.id) {
                currentCoopIsFavorite = isFavorite
            }
        } catch {
            logError(error)
        }
    }

    func loadCurrentCoopFavoriteStatus(for selectedRow: String?) {
        guard let coop = detail(for: selectedRow) else {
            currentCoopIsFavorite = false
            return
        }

        Task {
            do {
                if let isFavorite = try await RecordStore.coopFavoriteState(coopId: coop.id) {
                    currentCoopIsFavorite = isFavorite
                }
            } catch {
                logError(error)
            }
        }
    }

    private func detail(for rowId: String?) -> CoopListRowInfo? {
        guard let rowId else { return nil }
        return rows.first { $0.id == rowId }?.detail
    }
}
