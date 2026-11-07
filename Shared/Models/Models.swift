import Foundation
import GRDB
import SplatDatabase

struct RecordSelection<ID: Hashable> {
    private(set) var selectedIds: Set<ID> = []
    private(set) var isActive = false

    var selectedCount: Int {
        selectedIds.count
    }

    mutating func start() {
        isActive = true
    }

    mutating func cancel() {
        isActive = false
        selectedIds.removeAll()
    }

    mutating func toggle(_ id: ID) {
        start()
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    mutating func toggleAll(_ ids: [ID]) {
        start()
        let visibleIds = Set(ids)
        if selectedIds == visibleIds {
            selectedIds.removeAll()
        } else {
            selectedIds = visibleIds
        }
    }

    func contains(_ id: ID) -> Bool {
        selectedIds.contains(id)
    }
}

/// 可软删除 / 可收藏的记录（对战与打工）。
///
/// 两类记录的收藏、软删除、恢复行为完全一致，差异只在所属类型，
/// 因此统一由这个协议提供默认实现。
protocol RecordStatusToggleable {
    static var recordKind: SplatRecordKind { get }
    var id: Int64? { get }
    var isFavorite: Bool { get }
}

extension RecordStatusToggleable {
    func toggleFavorite() throws {
        try SplatDatabase.shared.setFavorite(!isFavorite, kind: Self.recordKind, ids: [id ?? 0])
    }

    func softDelete() throws {
        try SplatDatabase.shared.setDeleted(true, kind: Self.recordKind, ids: [id ?? 0])
    }

    func restore() throws {
        try SplatDatabase.shared.setDeleted(false, kind: Self.recordKind, ids: [id ?? 0])
    }
}

extension Coop: RecordStatusToggleable {
    static let recordKind = SplatRecordKind.coop

    var gradeName: String? {
        guard let afterGrade else { return nil }
        return "CoopGrade-\(afterGrade)".base64EncodedString
    }

    var clear: Bool {
        wave == 3 && rule != "TEAM_CONTEST" || wave == 5 && rule == "TEAM_CONTEST"
    }
}

extension Battle: RecordStatusToggleable {
    static let recordKind = SplatRecordKind.battle
}
