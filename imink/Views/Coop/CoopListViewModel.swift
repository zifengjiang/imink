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

    private init() {
        super.init(kind: .coop, navigationTitle: "全部打工")
    }

    /// 重新加载打工列表（保留给视图层调用的语义化入口）。
    func loadCoops(limit: Int = 50, offset: Int = 0, loadRecent: Bool = false) async {
        if loadRecent {
            filter = Filter()
        }
        await reload(limit: limit, offset: offset)
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
        guard let coop = detail(for: selectedRow) else { return }

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
