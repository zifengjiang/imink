import Foundation
import SwiftUI
import SplatDatabase
import GRDB
import Combine

struct CoopListItemInfo:Identifiable {
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

    var gradeName:String?{
        if let grade = grade {
            return "CoopGrade-\(grade)".base64EncodedString
        }
        return nil
    }
}

extension CoopListItemInfo: Codable, FetchableRecord, MutablePersistableRecord{

}

extension CoopListItemInfo {
    var _specie:Specie {
        return specie ? .octoling : .inkling
    }

    enum Specie: String,Codable {
        case inkling = "INKLING"
        case octoling = "OCTOLING"
    }
}


extension CoopListItemInfo.Specie {
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

extension CoopListItemInfo {
    enum Rule: String,Codable {
        case regular = "REGULAR"
        case bigRun = "BIG_RUN"
        case teamContest = "TEAM_CONTEST"
    }
}

extension CoopListItemInfo.Rule {
    var waveCount:Int {
        switch self {
        case .teamContest:
            return 5
        default:
            return 3
        }
    }
}


extension CoopListItemInfo {
    enum GradeDiff: String,Codable {
        case up = "UP"
        case down = "DOWN"
        case keep = "KEEP"
    }
}

extension CoopListItemInfo.GradeDiff {
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

let fetch_coop_list_item = """
SELECT
    coop.id,
    coop.rule AS RULE,
    coop.afterGrade AS grade,
    coop.afterGradePoint AS gradePoint,
    CASE
        WHEN coop.wave = 3 AND coop.rule != 'TEAM_CONTEST' AND coop.afterGradePoint < 999 THEN 'UP'
        WHEN (coop.wave = 2 AND coop.rule != 'TEAM_CONTEST') OR (coop.wave = 3 AND coop.rule != 'TEAM_CONTEST' AND coop.afterGradePoint = 999) THEN 'KEEP'
        WHEN coop.rule = 'TEAM_CONTEST' THEN NULL
        ELSE 'DOWN'
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
    coop_view AS coop -- Use coop_view for group information
    JOIN coopPlayerResult ON coopPlayerResult.coopId = coop.id
    JOIN imageMap ON coop.stageId = imageMap.id
    JOIN player ON player.coopPlayerResultId = coopPlayerResult.id
    LEFT JOIN imageMap AS bossImageMap ON coop.boss = bossImageMap.id
    LEFT JOIN coopWaveResult ON coopWaveResult.coopId = coop.id AND coopWaveResult.waveNumber = 4
    LEFT JOIN i18n AS bossI18n ON coopWaveResult.eventWave = bossI18n.id
WHERE
    coop.GroupID IN (
        SELECT DISTINCT GroupID -- Select the 10 most recent groups
        FROM coop_view
        ORDER BY playedTime DESC
--         LIMIT 10 OFFSET 10
    )
    AND coopPlayerResult.'order' = 0
    AND coop.accountId = 1
ORDER BY
    time DESC LIMIT ? OFFSET ?;
"""

extension SplatDatabase {
    func coops(limit:Int = 30, _ offset: Int = 0) -> AnyPublisher<[CoopListItemInfo], Error> {
        return ValueObservation.tracking { db in
            try Row.fetchAll(db, sql: fetch_coop_list_item, arguments: [limit,offset])
                .map { row in
                    try! CoopListItemInfo(row: row)
                }
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }

    func coop(id: Int64) -> AnyPublisher<Coop?, Error> {
        return ValueObservation.tracking { db in
            try Coop.fetchOne(db, key: id)
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }

    func coopPlayerResults(id: Int64) -> AnyPublisher<[CoopPlayerResult], Error> {
        return ValueObservation.tracking { db in
            try CoopPlayerResult
                .filter(Column("coopId") == id)
                .fetchAll(db)
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }

    func coopWaveResults(id: Int64) -> AnyPublisher<[CoopWaveResult], Error> {
        return ValueObservation.tracking { db in
            try CoopWaveResult
                .filter(Column("coopId") == id)
                .fetchAll(db)
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }

    func coopEnemyResults(id: Int64) -> AnyPublisher<[CoopEnemyResult], Error> {
        return ValueObservation.tracking { db in
            try CoopEnemyResult
                .filter(Column("coopId") == id)
                .fetchAll(db)
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }
}
