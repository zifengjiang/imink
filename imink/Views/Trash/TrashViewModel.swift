import Foundation
import Combine
import SplatDatabase

/// 回收站：展示并恢复 / 永久删除已软删除的对战与打工记录。
@MainActor
final class TrashViewModel: ObservableObject {
    @Published private(set) var deletedCoops: [Coop] = []
    @Published private(set) var deletedBattles: [Battle] = []
    @Published var showPermanentDeleteAlert = false

    private var cancellables: Set<AnyCancellable> = []

    init() {
        // 任一类记录发生变化后刷新回收站
        for kind in SplatRecordKind.allCases {
            NotificationCenter.default.publisher(for: kind.dataChangedNotification)
                .sink { [weak self] _ in
                    Task { await self?.loadData() }
                }
                .store(in: &cancellables)
        }
    }

    func loadData() async {
        do {
            async let coops = RecordStore.fetchDeletedCoops()
            async let battles = RecordStore.fetchDeletedBattles()
            deletedCoops = try await coops
            deletedBattles = try await battles
        } catch {
            logError(error)
            deletedCoops = []
            deletedBattles = []
        }
    }

    /// 已删除记录的数量。
    func deletedCount(_ kind: SplatRecordKind) -> Int {
        switch kind {
        case .coop: return deletedCoops.count
        case .battle: return deletedBattles.count
        }
    }

    /// 恢复某类记录中所有已删除的数据。
    func restoreAll(kind: SplatRecordKind) async {
        let totalCount = deletedCount(kind)

        let succeeded = await BatchOperation.run(
            title: "正在恢复",
            totalCount: totalCount,
            successTitle: "恢复完成",
            successSubtitle: { "已恢复 \($0) 条记录" },
            failureTitle: "恢复失败"
        ) { [deletedCoops, deletedBattles] reportProgress in
            let ids: [Int64]
            switch kind {
            case .coop: ids = deletedCoops.compactMap(\.id)
            case .battle: ids = deletedBattles.compactMap(\.id)
            }
            try await RecordStore.restore(ids: ids, kind: kind, onProgress: reportProgress)
        }

        if succeeded {
            await loadData()
        }
    }

    /// 永久删除某类记录中所有已删除的数据。
    func permanentlyDeleteAll(kind: SplatRecordKind) async {
        do {
            try await RecordStore.permanentlyDeleteAll(kind: kind)
            await loadData()
        } catch {
            logError(error)
            Toast.failure("永久删除失败", subtitle: error.localizedDescription)
        }
    }
}
