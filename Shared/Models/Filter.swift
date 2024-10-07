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

    
}
