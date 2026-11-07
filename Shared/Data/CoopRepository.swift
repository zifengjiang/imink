import Foundation
import GRDB
import SplatDatabase

/// 打工相关的只读查询。
///
/// 之前筛选页与玩家卡片里分散着多段手写 SQL，这里集中管理，
/// 便于统一维护索引、字段与账号过滤条件。
enum CoopRepository {
    /// 筛选页按武器类型分组的武器列表。
    static func weaponsByType(accountId: Int) async throws -> [String: [ImageMap]] {
        let weapons = try await SplatDatabase.shared.dbQueue.read { db in
            try ImageMap.fetchAll(db, sql: """
                SELECT DISTINCT im.*
                FROM imageMap im
                INNER JOIN weapon w ON im.id = w.imageMapId
                INNER JOIN coopPlayerResult cpr ON w.coopPlayerResultId = cpr.id
                INNER JOIN coop c ON cpr.coopId = c.id
                WHERE cpr.'order' = 0
                AND c.accountId = ?
                AND im.name LIKE 'Wst%'
                AND im.name NOT LIKE '%_O'
                AND im.name NOT LIKE '%01'
                AND im.name NOT LIKE '%Scope_00'
                AND im.name != 'Wst_Shooter_Normal_H'
                ORDER BY im.name ASC
                """, arguments: [accountId])
        }
        return Dictionary(grouping: weapons, by: \.weaponType)
    }

    /// 筛选页的打工地图列表。
    static func stages(accountId: Int) async throws -> [ImageMap] {
        try await SplatDatabase.shared.dbQueue.read { db in
            try ImageMap.fetchAll(db, sql: """
                SELECT DISTINCT im.*
                FROM imageMap im
                INNER JOIN coop c ON im.id = c.stageId
                WHERE c.accountId = ?
                ORDER BY im.name ASC
                """, arguments: [accountId])
        }
    }

    /// 按名称 / 昵称搜索一起打过工的玩家。
    static func searchPlayers(
        query: String,
        accountId: Int,
        limit: Int = 20
    ) async throws -> [PlayerSearchResult] {
        guard !query.isEmpty else { return [] }

        return try await SplatDatabase.shared.dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT
                    player.name,
                    player.byname,
                    player.nameId,
                    COUNT(DISTINCT coop.id) as playCount
                FROM player
                INNER JOIN coopPlayerResult ON player.coopPlayerResultId = coopPlayerResult.id
                INNER JOIN coop ON coopPlayerResult.coopId = coop.id
                WHERE coop.accountId = ?
                AND (player.name LIKE ? OR player.byname LIKE ?)
                AND player.isMyself != 1
                GROUP BY player.name, player.nameId
                HAVING playCount > 0
                ORDER BY playCount DESC, player.name ASC
                LIMIT ?
                """, arguments: [accountId, "%\(query)%", "%\(query)%", limit])
                .map { row in
                    PlayerSearchResult(
                        name: row["name"],
                        byname: row["byname"],
                        nameId: row["nameId"],
                        playCount: row["playCount"]
                    )
                }
        }
    }

    /// 与本机玩家一起打过工的次数（不含自己）。
    static func playCount(withPlayerName name: String, nameId: String, accountId: Int) async throws -> Int {
        try await SplatDatabase.shared.dbQueue.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(DISTINCT c.id)
                FROM coop c
                INNER JOIN coopPlayerResult cpr ON cpr.coopId = c.id
                INNER JOIN player p ON p.coopPlayerResultId = cpr.id
                WHERE c.accountId = ? AND p.name = ? AND p.nameId = ?
                """, arguments: [accountId, name, nameId]) ?? 0
        }
    }

    /// 本地最早一条打工记录的时间，作为筛选时间范围的起点。
    static func earliestPlayedTime() -> Date {
        let earliest = try? SplatDatabase.shared.dbQueue.read { db in
            try Date.fetchOne(db, sql: "SELECT MIN(playedTime) FROM coop")
        }
        return earliest ?? Date(timeIntervalSince1970: 0)
    }
}

/// 玩家搜索结果。
struct PlayerSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let byname: String
    let nameId: String
    let playCount: Int

    var displayName: String {
        byname.isEmpty ? name : "\(name) (\(byname))"
    }
}

extension ImageMap {
    /// 武器图片名中的类型段，例如 `Wst_Shooter_Normal_00` → `Shooter`。
    var weaponType: String {
        let parts = name.split(separator: "_")
        return parts.count > 1 ? String(parts[1]) : "Unknown"
    }
}
