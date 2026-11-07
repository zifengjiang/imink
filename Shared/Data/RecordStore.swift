import Foundation
import SplatDatabase

/// 对战 / 打工记录的写入入口。
///
/// 真正的 SQL 与批处理都在 `SplatDatabase` 里（`setDeleted` / `setFavorite` /
/// `toggleFavorite` / `permanentlyDeleteSoftDeleted`），这里只补充两类 App 侧职责：
/// - 分批推进并向 UI 汇报进度；
/// - 写入后广播数据变更通知，让列表与回收站自动刷新。
enum RecordStore {
    // MARK: - 收藏

    /// 批量翻转收藏状态。
    static func toggleFavorites(ids: [Int64], kind: SplatRecordKind) async throws {
        try SplatDatabase.shared.toggleFavorite(kind: kind, ids: ids)
        postDataChanged(kind)
    }

    /// 读取单条打工记录的收藏状态。
    static func coopFavoriteState(coopId: Int64) async throws -> Bool? {
        try await SplatDatabase.shared.dbQueue.read { db in
            try Coop.fetchOne(db, key: coopId)?.isFavorite
        }
    }

    /// 切换单条打工记录的收藏状态，返回切换后的状态。
    @discardableResult
    static func toggleCoopFavorite(coopId: Int64) async throws -> Bool? {
        guard let isFavorite = try await coopFavoriteState(coopId: coopId) else { return nil }

        try SplatDatabase.shared.setFavorite(!isFavorite, kind: .coop, ids: [coopId])
        return !isFavorite
    }

    // MARK: - 软删除 / 恢复

    /// 批量软删除（移入回收站）。
    static func softDelete(
        ids: [Int64],
        kind: SplatRecordKind,
        onProgress: @escaping (Int) async -> Void = { _ in }
    ) async throws {
        try await setDeleted(true, ids: ids, kind: kind, onProgress: onProgress)
    }

    /// 批量恢复软删除的记录。
    static func restore(
        ids: [Int64],
        kind: SplatRecordKind,
        onProgress: @escaping (Int) async -> Void = { _ in }
    ) async throws {
        try await setDeleted(false, ids: ids, kind: kind, onProgress: onProgress)
    }

    // MARK: - 回收站

    static func fetchDeletedCoops() async throws -> [Coop] {
        try await SplatDatabase.shared.fetchDeletedCoops()
    }

    static func fetchDeletedBattles() async throws -> [Battle] {
        try await SplatDatabase.shared.fetchDeletedBattles()
    }

    /// 永久删除指定记录（含关联表数据）。
    static func permanentlyDelete(ids: [Int64], kind: SplatRecordKind) async throws {
        try SplatDatabase.shared.deleteRecords(kind: kind, ids: ids)
        postDataChanged(kind)
    }

    /// 永久删除某类记录中所有已软删除的数据。
    static func permanentlyDeleteAll(kind: SplatRecordKind) async throws {
        try SplatDatabase.shared.permanentlyDeleteSoftDeleted(kind)
        postDataChanged(kind)
    }

    // MARK: - 内部

    private static func setDeleted(
        _ isDeleted: Bool,
        ids: [Int64],
        kind: SplatRecordKind,
        onProgress: @escaping (Int) async -> Void
    ) async throws {
        guard !ids.isEmpty else { return }

        var processed = 0
        for batch in SplatDatabase.batches(ids) {
            try SplatDatabase.shared.setDeleted(isDeleted, kind: kind, ids: batch)
            processed += batch.count
            await onProgress(processed)
            await Task.yield()
        }

        postDataChanged(kind)
    }

    private static func postDataChanged(_ kind: SplatRecordKind) {
        NotificationCenter.default.post(name: kind.dataChangedNotification, object: nil)
    }
}
