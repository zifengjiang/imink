import Foundation
import GRDB
import SplatDatabase

func getCoopEarliestPlayedTime() -> Date{
    try! SplatDatabase.shared.dbQueue.read { db in
        try Date.fetchOne(db, sql: "SELECT MIN(playedTime) FROM coop") ?? Date(timeIntervalSince1970: 0)
    }
}

struct Filter {
    var modes: Set<String> = []
    var rules: Set<String> = []
    var stageIds: Set<Int> = []
    var weaponIds: Set<Int> = []
    var start: Date = getCoopEarliestPlayedTime()
    var end: Date = Date()

    func buildCoopQuery(accountId: Int = AppUserDefaults.shared.accountId, limit:Int, offset:Int) -> SQLRequest<Row> {
        var conditions: [String] = []
        var arguments: [DatabaseValueConvertible] = []

        if !rules.isEmpty {
            let array = Array(rules)
            let rulePlaceholders = array.map { _ in "?" }.joined(separator: ", ")
            conditions.append("coop.rule IN (\(rulePlaceholders))")
            arguments.append(contentsOf: array)
        }

        if !stageIds.isEmpty {
            let array = Array(stageIds)
            let stageIdPlaceholders = array.map { _ in "?" }.joined(separator: ", ")
            conditions.append("coop.stageId IN (\(stageIdPlaceholders))")
            arguments.append(contentsOf: array)
        }

        if !weaponIds.isEmpty {
            let array = Array(weaponIds)
            let weaponIdPlaceholders = array.map { _ in "?" }.joined(separator: ", ")
            conditions.append("weapon.imageMapId IN (\(weaponIdPlaceholders))")
            arguments.append(contentsOf: array)
        }


            conditions.append("coop.playedTime >= ?")
            arguments.append(start)



            conditions.append("coop.playedTime <= ?")
            arguments.append(end)
        

        let whereClause = conditions.isEmpty ? "1" : conditions.joined(separator: " AND ")
        let sql = """
            SELECT DISTINCT
            coop.id,
            coop.rule AS RULE,
            coop.afterGrade AS grade,
            coop.afterGradePoint AS gradePoint,
            CASE WHEN coop.wave = 3
            AND coop.rule != 'TEAM_CONTEST'
            AND coop.afterGradePoint < 999 THEN
            'UP'
            WHEN (coop.wave = 2
            AND coop.rule != 'TEAM_CONTEST')
            OR(coop.wave = 3
                AND coop.rule != 'TEAM_CONTEST'
                AND coop.afterGradePoint = 999) THEN
            'KEEP'
            WHEN coop.rule = 'TEAM_CONTEST' THEN
            NULL
            ELSE
            'DOWN'
            END AS gradeDiff,
            coop.dangerRate,
            coopPlayerResult.defeatEnemyCount AS enemyDefeatCount,
            player.species AS specie,
            imageMap.nameId AS stage,
            bossI18n.key AS boss,
            coop.bossDefeated AS haveBossDefeated,
            coop.wave AS resultWave,
            coop.egg AS goldenEgg,
            coop.powerEgg,
            coopPlayerResult.rescueCount AS rescue,
            coopPlayerResult.rescuedCount AS rescued,
            coop.playedTime AS time,
            coop.GroupID
            FROM
            coop_view AS coop
            JOIN coopPlayerResult ON coopPlayerResult.coopId = coop.id
            JOIN imageMap ON coop.stageId = imageMap.id
            JOIN player ON player.coopPlayerResultId = coopPlayerResult.id
            LEFT JOIN imageMap AS bossImageMap ON coop.boss = bossImageMap.id
            LEFT JOIN coopWaveResult ON coopWaveResult.coopId = coop.id
            AND coopWaveResult.waveNumber = 4
            LEFT JOIN i18n AS bossI18n ON coopWaveResult.eventWave = bossI18n.id
            LEFT JOIN weapon ON weapon.coopPlayerResultId = coopPlayerResult.id
            WHERE \(whereClause)
            AND coop.accountId = \(accountId)
            AND coopPlayerResult.'order' = 0
            ORDER BY
            time DESC
            LIMIT \(limit) OFFSET \(offset)
        """

        return SQLRequest<Row>(sql: sql, arguments: StatementArguments(arguments))
    }
}
