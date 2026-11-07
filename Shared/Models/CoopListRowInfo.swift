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
                try CoopListRowInfo(row: row)
            }
    }
    .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
    .eraseToAnyPublisher()
}

func coops(filter:Filter = Filter(), limit:Int = 30, _ offset: Int = 0) async -> [CoopListRowInfo] {
    let results: [CoopListRowInfo]
    do {
        results = try await SplatDatabase.shared.dbQueue.read { db in
            try Row.fetchAll(db, filter.buildCoopQuery(limit:limit, offset:offset))
                .map { row in
                    try CoopListRowInfo(row: row)
                }
        }
    } catch {
        logError(error)
        return []
    }
    
    // 先按rule排序，再按时间排序
    return results.sorted { first, second in
        if first.GroupId != second.GroupId {
            return first.GroupId > second.GroupId
        }
        return first.time > second.time // 时间降序
    }
}


