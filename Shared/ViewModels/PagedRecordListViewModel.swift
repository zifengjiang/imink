import Foundation
import Combine
import GRDB
import SplatDatabase

/// 对战 / 打工列表通用的「分页 + 班次分组」视图模型。
///
/// 子类只需要提供数据来源（取一页记录、取班次卡片）以及批量操作的实现，
/// 分页游标、班次卡片插入、登录态与数据变更监听都在这里统一处理。
@MainActor
class PagedRecordListViewModel<Detail: GroupedRecord, Card: GroupStatusCard>: ObservableObject {
    @Published private(set) var rows: [RecordListRow<Detail, Card>] = []
    @Published var navigationTitle: String
    @Published var filter = Filter()

    /// 当前列表对应的记录类型，批量操作与变更通知都由它决定。
    let kind: SplatRecordKind

    private var offset = 0
    private var currentGroupId: Int64 = 0
    private var cancellables = Set<AnyCancellable>()

    /// - Parameters:
    ///   - kind: 记录类型（对战 / 打工）。
    ///   - navigationTitle: 列表标题的初始值。
    init(kind: SplatRecordKind, navigationTitle: String) {
        self.kind = kind
        self.navigationTitle = navigationTitle
        let dataChanged = kind.dataChangedNotification

        AppState.shared.$isLogin
            .sink { [weak self] isLogin in
                self?.handleLoginStateChange(isLogin: isLogin)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: dataChanged)
            .sink { [weak self] _ in
                self?.handleDataChanged()
            }
            .store(in: &cancellables)
    }

    // MARK: - 子类需要实现的数据来源

    /// 取一页列表记录。
    func fetchPage(filter: Filter, limit: Int, offset: Int) async -> [Detail] { [] }

    /// 取单个班次的统计卡片。
    func fetchCard(groupId: Int64, accountId: Int) async throws -> Card? { nil }

    /// 分页取班次统计卡片。
    func fetchCards(accountId: Int, offset: Int) async throws -> [Card] { [] }

    // MARK: - 批量操作

    /// 批量切换收藏状态。
    func toggleFavorites(ids: [Int64]) async throws {
        try await RecordStore.toggleFavorites(ids: ids, kind: kind)
    }

    /// 批量软删除。
    func softDelete(ids: [Int64], onProgress: @escaping (Int) async -> Void) async throws {
        try await RecordStore.softDelete(ids: ids, kind: kind, onProgress: onProgress)
    }

    // MARK: - 加载

    /// 重新加载第一页。
    func reload(limit: Int = 50, offset: Int = 0) async {
        currentGroupId = 0
        self.offset = 0
        let page = await measureTime(title: "\(Detail.self) page") {
            await fetchPage(filter: filter, limit: limit, offset: offset)
        }
        rows = await makeRows(from: page)
    }

    /// 追加下一页。
    func loadMore(limit: Int = 10) async {
        let page = await fetchPage(filter: filter, limit: limit, offset: offset)
        rows.append(contentsOf: await makeRows(from: page))
    }

    /// 加载班次卡片列表。
    func loadCards(accountId: Int = AppUserDefaults.shared.accountId, offset: Int = 0) async {
        do {
            rows = try await fetchCards(accountId: accountId, offset: offset).map(RecordListRow.init(card:))
        } catch {
            logError(error)
        }
    }

    /// 追加更多班次卡片。
    func loadMoreCards() async {
        do {
            let cards = try await fetchCards(accountId: AppUserDefaults.shared.accountId, offset: rows.count)
            rows.append(contentsOf: cards.map(RecordListRow.init(card:)))
        } catch {
            logError(error)
        }
    }

    // MARK: - 内部

    private func handleLoginStateChange(isLogin: Bool) {
        guard isLogin else {
            rows = []
            return
        }
        Task { await reload() }
    }

    private func handleDataChanged() {
        Task { await reload() }
    }

    /// 把一页记录转换成带班次卡片的分组行。
    private func makeRows(from page: [Detail]) async -> [RecordListRow<Detail, Card>] {
        var result: [RecordListRow<Detail, Card>] = []
        result.reserveCapacity(page.count + 1)
        let accountId = AppUserDefaults.shared.accountId

        for detail in page {
            if detail.GroupId != currentGroupId {
                currentGroupId = detail.GroupId
                if let card = try? await fetchCard(groupId: currentGroupId, accountId: accountId) {
                    result.append(.init(card: card))
                }
            }
            result.append(.init(detail: detail))
        }

        offset += page.count
        return result
    }
}
