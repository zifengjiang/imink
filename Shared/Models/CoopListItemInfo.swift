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

func coops(filter:Filter = Filter(), limit:Int = 30, _ offset: Int = 0) -> AnyPublisher<[CoopListItemInfo], Error> {
    return ValueObservation.tracking { db in
        print("fetch_coop_list_item")
        return try Row.fetchAll(db, filter.buildCoopQuery(limit:limit, offset:offset))
            .map { row in
                try! CoopListItemInfo(row: row)
            }
    }
    .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
    .eraseToAnyPublisher()
}

func coops(filter:Filter = Filter(), limit:Int = 30, _ offset: Int = 0) async -> [CoopListItemInfo] {
    return try! await SplatDatabase.shared.dbQueue.read { db in
        try Row.fetchAll(db, filter.buildCoopQuery(limit:limit, offset:offset))
            .map { row in
                try! CoopListItemInfo(row: row)
            }
    }
}

