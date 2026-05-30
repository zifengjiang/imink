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

enum RecordBatchOperationService {
    static let defaultBatchSize = 50

    static func batches<ID>(_ ids: [ID], batchSize: Int = defaultBatchSize) -> [[ID]] {
        guard batchSize > 0 else { return [] }

        return stride(from: 0, to: ids.count, by: batchSize).map { startIndex in
            let endIndex = min(startIndex + batchSize, ids.count)
            return Array(ids[startIndex..<endIndex])
        }
    }

    static func toggleBattleFavorites(ids: [Int64]) async throws {
        for id in ids {
            if let battle = try await SplatDatabase.shared.dbQueue.read({ db in
                try Battle.fetchOne(db, key: id)
            }) {
                try battle.toggleFavorite()
            }
        }
    }

    static func toggleCoopFavorites(ids: [Int64]) async throws {
        for id in ids {
            if let coop = try await SplatDatabase.shared.dbQueue.read({ db in
                try Coop.fetchOne(db, key: id)
            }) {
                try coop.toggleFavorite()
            }
        }
    }

    static func softDeleteBattles(
        ids: [Int64],
        onProgress: @escaping (Int) async -> Void = { _ in }
    ) async throws {
        try await softDelete(table: "battle", ids: ids, onProgress: onProgress)
    }

    static func softDeleteCoops(
        ids: [Int64],
        onProgress: @escaping (Int) async -> Void = { _ in }
    ) async throws {
        try await softDelete(table: "coop", ids: ids, onProgress: onProgress)
    }

    private static func softDelete(
        table: String,
        ids: [Int64],
        onProgress: @escaping (Int) async -> Void
    ) async throws {
        var processedCount = 0

        for batch in batches(ids) {
            let placeholders = batch.map { _ in "?" }.joined(separator: ",")

            try await SplatDatabase.shared.dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE \(table) SET isDeleted = 1 WHERE id IN (\(placeholders))",
                    arguments: StatementArguments(batch)
                )
            }

            processedCount += batch.count
            await onProgress(processedCount)
            await Task.yield()
        }
    }
}


extension Coop {
    var gradeName: String?{
        if let afterGrade = afterGrade {
            return "CoopGrade-\(afterGrade)".base64EncodedString
        }
        return nil
    }

    var clear:Bool{
        wave == 3 && rule != "TEAM_CONTEST" || wave == 5 && rule == "TEAM_CONTEST"
    }
    
    // 软删除和喜爱功能扩展
    func toggleFavorite() throws {
        if isFavorite {
            try SplatDatabase.shared.unmarkCoopAsFavorite(coopId: id ?? 0)
        } else {
            try SplatDatabase.shared.markCoopAsFavorite(coopId: id ?? 0)
        }
    }
    
    func softDelete() throws {
        try SplatDatabase.shared.softDeleteCoop(coopId: id ?? 0)
    }
    
    func restore() throws {
        try SplatDatabase.shared.restoreCoop(coopId: id ?? 0)
    }
}

extension Battle {
    // 软删除和喜爱功能扩展
    func toggleFavorite() throws {
        if isFavorite {
            try SplatDatabase.shared.unmarkBattleAsFavorite(battleId: id ?? 0)
        } else {
            try SplatDatabase.shared.markBattleAsFavorite(battleId: id ?? 0)
        }
    }
    
    func softDelete() throws {
        try SplatDatabase.shared.softDeleteBattle(battleId: id ?? 0)
    }
    
    func restore() throws {
        try SplatDatabase.shared.restoreBattle(battleId: id ?? 0)
    }
}
