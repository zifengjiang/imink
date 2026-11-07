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
        await reload(limit: limit, offset: offset)
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
