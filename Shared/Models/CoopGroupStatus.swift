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

    var suppliedWeapons: [String]? = nil
    var stageImage: String? = nil
    var stageName: String? = nil

    var failure:Int{
        count - clear - disconnect
    }
}

extension CoopGroupStatus:PreComputable{
    static func create(from db: Database, identifier: (Int, Int)) throws -> CoopGroupStatus? {
        let (groupId, accountId) = identifier
        if var status = try CoopGroupStatus.fetchOne(db, sql: "SELECT * FROM coop_group_status_view WHERE accountId = ? AND GroupID = ?", arguments: [accountId, groupId]) {
            status.suppliedWeapons = Array(0..<4).compactMap { getImageName(by: status.suppliedWeapon[$0], db: db) }
            status.stageImage = getImageName(by: status.stageId, db: db)
            status.stageName = getImageNameId(by: status.stageId, db: db)
            return status
        }
        return nil
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


