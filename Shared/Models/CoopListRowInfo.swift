import Foundation
import SwiftUI
import SplatDatabase
import GRDB
import Combine

struct CoopListRowInfo:Identifiable {
    var id: Int64
    var rule: Rule
    var grade: Int?
    var gradePoint: Int?
    var gradeDiff: GradeDiff?
    var dangerRate: Double
    var enemyDefeatCount: Int
    var specie:Bool
    var stage: String
    var boss: String?
    var haveBossDefeated: Bool?
    var resultWave: Int
    var goldenEgg: Int
    var powerEgg: Int
    var rescue: Int
    var rescued: Int
    var time:Date
    var GroupId: Int64
    var enemyKindCount: Int

    var gradeName:String?{
        if let grade = grade {
            return "CoopGrade-\(grade)".base64EncodedString
        }
        return nil
    }

    var height:CGFloat{
        CGFloat(610 + (self.resultWave != -2 ? 160 : 0) + self.enemyKindCount*60) + (self.rule == .teamContest && resultWave > 3 ? 160 : 0)
    }
}


extension CoopListRowInfo: Codable, FetchableRecord, MutablePersistableRecord{

}

extension CoopListRowInfo {
    var _specie:Specie {
        return specie ? .octoling : .inkling
    }

    enum Specie: String,Codable {
        case inkling = "INKLING"
        case octoling = "OCTOLING"
    }
}


extension CoopListRowInfo.Specie {
    var coopRescue:Image {
        switch self {
        case .inkling:
            return Image(.rescueINKLING)
        case .octoling:
            return Image(.rescueOCTOLING)
        }
    }

    var coopRescued:Image {
        switch self {
        case .inkling:
            return Image(.rescuedINKLING)
        case .octoling:
            return Image(.rescuedOCTOLING)
        }
    }
}

extension CoopListRowInfo {
    enum Rule: String,Codable {
        case regular = "REGULAR"
        case bigRun = "BIG_RUN"
        case teamContest = "TEAM_CONTEST"
    }
}

extension CoopListRowInfo.Rule {
    var waveCount:Int {
        switch self {
        case .teamContest:
            return 5
        default:
            return 3
        }
    }
}


extension CoopListRowInfo {
    enum GradeDiff: String,Codable {
        case up = "UP"
        case down = "DOWN"
        case keep = "KEEP"
    }
}

extension CoopListRowInfo.GradeDiff {
    var image:Image {
        switch self {
        case .up:
            return Image(.UP)
        case .down:
            return Image(.DOWN)
        case .keep:
            return Image(.KEEP)
        }
    }
}

func coops(filter:Filter = Filter(), limit:Int = 30, _ offset: Int = 0) -> AnyPublisher<[CoopListRowInfo], Error> {
    return ValueObservation.tracking { db in
        print("fetch_coop_list_item")
        return try Row.fetchAll(db, filter.buildCoopQuery(limit:limit, offset:offset))
            .map { row in
                try! CoopListRowInfo(row: row)
            }
    }
    .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
    .eraseToAnyPublisher()
}

func coops(filter:Filter = Filter(), limit:Int = 30, _ offset: Int = 0) async -> [CoopListRowInfo] {
    return try! await SplatDatabase.shared.dbQueue.read { db in
        try Row.fetchAll(db, filter.buildCoopQuery(limit:limit, offset:offset))
            .map { row in
                try! CoopListRowInfo(row: row)
            }
    }
}


extension Filter{
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
            coop.GroupID,
            (SELECT COUNT(*) 
            FROM coopEnemyResult 
            WHERE coopEnemyResult.coopId = coop.id) AS enemyKindCount
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
