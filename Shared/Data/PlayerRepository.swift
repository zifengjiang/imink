import Foundation
import GRDB
import SplatDatabase

/// 玩家数据的批量查询与维护。
enum PlayerRepository {
    /// 尚未补齐 `bynameFormatted` 的玩家数量。
    static func missingBynameFormattedCount() async throws -> Int {
        try await SplatDatabase.shared.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player WHERE bynameFormatted IS NULL") ?? 0
        }
    }

    /// 补齐一批玩家的 `bynameFormatted`，返回本批实际处理的条数。
    @discardableResult
    static func backfillBynameFormatted(limit: Int) async throws -> Int {
        try await SplatDatabase.shared.dbQueue.write { db in
            let players = try Row.fetchAll(
                db,
                sql: "SELECT id, byname FROM player WHERE bynameFormatted IS NULL LIMIT ?",
                arguments: [limit]
            )

            for player in players {
                let playerId: Int64 = player["id"]
                let byname: String = player["byname"]

                guard let formatted = formatBynameSync(byname) else { continue }

                // 男性标记：0 未知、1 男性、2 女性
                let maleFlag: UInt16 = formatted.male.map { $0 ? 1 : 2 } ?? 0
                let bynameFormatted = PackableNumbers([
                    i18nId(for: formatted.adjective, db: db) ?? 0,
                    i18nId(for: formatted.subject, db: db) ?? 0,
                    maleFlag
                ])

                try db.execute(
                    sql: "UPDATE player SET bynameFormatted = ? WHERE id = ?",
                    arguments: [bynameFormatted.databaseValue, playerId]
                )
            }

            return players.count
        }
    }

    private static func i18nId(for key: String, db: Database) -> UInt16? {
        let row = try? Row.fetchOne(db, sql: "SELECT id FROM i18n WHERE key = ?", arguments: [key])
        return row?["id"] as UInt16?
    }
}

/// 名称牌编辑器用到的图片资源。
enum ImageMapRepository {
    /// 名称牌背景。
    static func nameplateBackgrounds() async throws -> [ImageMap] {
        try await SplatDatabase.shared.dbQueue.read { db in
            try ImageMap.fetchAll(db, sql: "SELECT * FROM imageMap WHERE name LIKE 'Npl_%' ORDER BY name")
        }
    }

    /// 名称牌徽章。
    static func nameplateBadges() async throws -> [ImageMap] {
        try await SplatDatabase.shared.dbQueue.read { db in
            try ImageMap.fetchAll(db, sql: "SELECT * FROM imageMap WHERE name LIKE 'Badge_%' ORDER BY name")
        }
    }
}
