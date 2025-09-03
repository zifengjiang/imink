import GRDB
import SwiftUI
import SplatDatabase
import Foundation
import Combine

struct CoopGroupStatus: FetchableRecord, Decodable {
    var accountId: Int
    var groupId: Int
    var rule: String
    var suppliedWeapon: PackableNumbers
    var stageId:UInt16
    var startTime: Date
    var endTime: Date
    var avg_defeatEnemyCount: Double
    var avg_deliverCount: Double
    var avg_goldenAssistCount: Double
    var avg_goldenDeliverCount: Double
    var avg_rescueCount: Double
    var avg_rescuedCount: Double
    var goldScale:Int
    var silverScale:Int
    var bronzeScale:Int
    var clear:Int
    var disconnect:Int
    var highestScore: Int?
    var highestEgg: Int
    var count: Int

    var _suppliedWeapon: [ImageMap]? = []
    var _stage: ImageMap? = nil


    var failure:Int{
        count - clear - disconnect
    }

    var clearRate:Double {
        return Double(clear) / Double(count)
    }
}

extension CoopGroupStatus:PreComputable{
    static func create(from db: Database, identifier: (Int, Int)) throws -> CoopGroupStatus? {
        let (groupId, accountId) = identifier
        if var status = try CoopGroupStatus.fetchOne(db, sql: "SELECT * FROM coop_group_status_view WHERE accountId = ? AND GroupID = ?", arguments: [accountId, groupId]) {
            status._suppliedWeapon = try Array(0..<4).compactMap { try ImageMap.fetchOne(db, key: status.suppliedWeapon[$0])}
            status._stage = try ImageMap.fetchOne(db, key: status.stageId)
            let rule:Schedule.Rule = status.rule == "REGULAR" ? .salmonRun : (status.rule == "TEAM_CONTEST" ?  .teamContest : .bigRun)
            if let schedule = try Schedule.fetchOne(db, sql: "SELECT * FROM schedule WHERE ? BETWEEN startTime AND endTime AND mode = ? AND rule1 = ?", arguments: [status.startTime, Schedule.Mode.salmonRun.rawValue, rule.rawValue]){
                status.startTime = schedule.startTime
                status.endTime = schedule.endTime
            }
            return status
        }
        return nil
    }

    static func create(from db: Database, identifier: (Int, Int)) throws -> [CoopGroupStatus] {
        let (accountId, offset) = identifier
        var rows = try CoopGroupStatus.fetchAll(db, sql: "SELECT * FROM coop_group_status_view WHERE accountId = ? ORDER BY GroupID DESC LIMIT 10 OFFSET ?", arguments: [accountId, offset])
        for index in rows.indices {
            rows[index]._suppliedWeapon = try Array(0..<4).compactMap { try ImageMap.fetchOne(db, key: rows[index].suppliedWeapon[$0])}
            rows[index]._stage = try ImageMap.fetchOne(db, key: rows[index].stageId)
            let rule:Schedule.Rule = rows[index].rule == "REGULAR" ? .salmonRun : (rows[index].rule == "TEAM_CONTEST" ?  .teamContest : .bigRun)
            if let schedule = try Schedule.fetchOne(db, sql: "SELECT * FROM schedule WHERE ? BETWEEN startTime AND endTime AND mode = ? AND rule1 = ?", arguments: [rows[index].startTime, Schedule.Mode.salmonRun.rawValue, rule.rawValue]){
                rows[index].startTime = schedule.startTime
                rows[index].endTime = schedule.endTime
            }
        }
        return rows
    }
}

extension CoopGroupStatus{
    static let defaultValue:CoopGroupStatus = .init(accountId: 1, groupId: 1, rule: "", suppliedWeapon: .init([0]), stageId: 0, startTime: Date(), endTime: Date(), avg_defeatEnemyCount: 0, avg_deliverCount: 0, avg_goldenAssistCount: 0, avg_goldenDeliverCount: 0, avg_rescueCount: 0, avg_rescuedCount: 0, goldScale: 0, silverScale: 0, bronzeScale: 0, clear: 0, disconnect: 0, highestEgg: 0, count: 0)
}

struct CoopPlayerStatus:FetchableRecord, Decodable{
    var name: String
    var byname: String
    var bynameFormatted: PackableNumbers?
    var nameId: String
    var nameplate: PackableNumbers
    var nameplateTextColor: PackableNumbers
    var uniformId: Int
    var defeatEnemyCount: Double
    var deliverCount: Double
    var goldenAssistCount: Double
    var goldenDeliverCount: Double
    var rescueCount: Double
    var rescuedCount: Double
    var count: Int
    
    // MARK: - Computed
    var uniformName: String? = nil
    var _nameplate: Nameplate? = nil
    var _bynameFormatted: FormattedByname? = nil

    var id:String{
        "\(name)-\(byname)-\(nameId)"
    }

    enum CodingKeys: String, CodingKey {
        case name
        case byname
        case bynameFormatted
        case nameId
        case nameplate
        case nameplateTextColor
        case uniformId
        case defeatEnemyCount
        case deliverCount
        case goldenAssistCount
        case goldenDeliverCount
        case rescueCount
        case rescuedCount
        case count
    }
}

extension CoopPlayerStatus: Equatable {
    static func == (lhs: CoopPlayerStatus, rhs: CoopPlayerStatus) -> Bool {
        return lhs.id == rhs.id
    }
}

extension CoopPlayerStatus: PreComputable{
    static func create(from db: Database, identifier: (Int,Int)) throws -> [CoopPlayerStatus] {
        let (groupId, accountId) = identifier
        var rows = try CoopPlayerStatus.fetchAll(db, SplatDatabaseSQL.coop_player_status(accountId: accountId, GroupID: groupId).request)
        for index in rows.indices {
            rows[index]._nameplate = .init(nameplate: rows[index].nameplate, textColor: rows[index].nameplateTextColor, db: db)
            rows[index].uniformName = try ImageMap.fetchOne(db, key: rows[index].uniformId)?.name
            if let bynameFormatted = rows[index].bynameFormatted {
                rows[index]._bynameFormatted = .init(with: bynameFormatted, db: db)
            }
        }
        return rows
    }
}

struct CoopWaveStatus: FetchableRecord, Decodable {
    var eventWaveGroup: String?
    var waterLevel: Int
    var deliverNorm: Double?
    var goldenPopCount: Double
    var teamDeliverCount: Double?
    var failCount: Int
    var successCount: Int
}

extension CoopWaveStatus: FetchableFromDatabase{
    static func fetchRequest(accountId: Int, groupId: Int) -> SQLRequest<Row> {
        return SplatDatabaseSQL.wave_result(accountId: accountId, GroupID: groupId).request
    }
}

extension CoopWaveStatus: PreComputable {
    static func create(from db: Database, identifier: (Int, Int)) throws -> [CoopWaveStatus] {
        let (groupId, accountId) = identifier
        return try CoopWaveStatus.fetchAll(db, SplatDatabaseSQL.wave_result(accountId: accountId, GroupID: groupId).request)
    }
}


struct CoopWeaponStatus:FetchableRecord, Decodable {
    var name: String
    var nameId: String
    var count:Int
}

extension CoopWeaponStatus:FetchableFromDatabase{
    static func fetchRequest(accountId: Int, groupId: Int) -> SQLRequest<Row> {
        return SplatDatabaseSQL.weapon_status(accountId: accountId, GroupID: groupId).request
    }
}

extension CoopWeaponStatus: PreComputable {
    static func create(from db: Database, identifier: (Int, Int)) throws -> [CoopWeaponStatus] {
        let (groupId, accountId) = identifier
        return try CoopWeaponStatus.fetchAll(db, SplatDatabaseSQL.weapon_status(accountId: accountId, GroupID: groupId).request)
    }
}


struct CoopEnemyStatus:FetchableRecord, Decodable {
    var name:String
    var nameId:String
    var totalTeamDefeatCount:Int
    var totalDefeatCount:Int
    var totalPopCount:Int
}

extension CoopEnemyStatus:FetchableFromDatabase{
    static func fetchRequest(accountId: Int, groupId: Int) -> SQLRequest<Row> {
        return SplatDatabaseSQL.enemy_status(accountId: accountId, GroupID: groupId).request
    }
}

extension CoopEnemyStatus: PreComputable {
    static func create(from db: Database, identifier: (Int, Int)) throws -> [CoopEnemyStatus] {
        let (groupId, accountId) = identifier
        return try CoopEnemyStatus.fetchAll(db, SplatDatabaseSQL.enemy_status(accountId: accountId, GroupID: groupId).request)
    }
}


