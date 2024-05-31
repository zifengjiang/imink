import GRDB
import SwiftUI
import SplatDatabase
import Foundation
import Combine

struct CoopGroupStatus: FetchableRecord, Decodable {
    var accountId: Int
    var groupId: Int
    var rule: String
    @Packable var suppliedWeapon: PackableNumbers
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

    var failure:Int{
        count - clear - disconnect
    }
}

extension CoopGroupStatus{
    var suppliedWeapons: [String] {
        do {
            return try SplatDatabase.shared.dbQueue.read { db in
                return Array(0..<4).compactMap { getImageName(by: suppliedWeapon[$0], db: db)}
            }
        } catch {
            print("Error accessing database: \(error)")
            return []
        }
    }

    var stageImage: Image {
        do {
            return Image(try SplatDatabase.shared.dbQueue.read { getImageName(by: stageId, db: $0) })
        }catch{
            return Image(.dummyStage)
        }
    }

    var stageName: String {
        do{
            return try SplatDatabase.shared.dbQueue.read { db in
                getImageNameId(by: stageId, db: db)
            }
        }catch{
            return "DummyStage"
        }
    }
}

extension SplatDatabase{
    func coopGroupStatus(id:Int) -> AnyPublisher<CoopGroupStatus?, Error> {
        ValueObservation
            .tracking { db in
                try CoopGroupStatus.fetchOne(db, sql: "SELECT * FROM  coop_group_status_view WHERE accountId = ? AND GroupID = ?", arguments: [AppUserDefaults.shared.accountId, id])
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}

struct CoopWaveStatus: FetchableRecord, Decodable {
    var eventWaveGroup: String
    var waterLevel: Int
    var avgDeliverNorm: Double?
    var avgGoldenPopCount: Double
    var avgTeamDeliverCount: Double?
    var count: Int
}

extension SplatDatabase{
    func coopWaveStatus(id:Int) -> AnyPublisher<[CoopWaveStatus], Error> {
        ValueObservation
            .tracking { db in
                try CoopWaveStatus.fetchAll(db, SplatDatabaseSQL.wave_result(accountId: AppUserDefaults.shared.accountId, GroupID: id).request)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}

struct CoopWeaponStatus:FetchableRecord, Decodable {
    var weaponId:String
    var count:Int
}

extension SplatDatabase{
    func coopWeaponStatus(id:Int) -> AnyPublisher<[CoopWeaponStatus], Error> {
        ValueObservation
            .tracking { db in
                try CoopWeaponStatus.fetchAll(db, SplatDatabaseSQL.weapon_status(accountId: AppUserDefaults.shared.accountId, GroupID: id).request)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}

struct CoopEnemyStatus:FetchableRecord, Decodable {
    var name:String
    var totalTeamDefeatCount:Int
    var totalDefeatCount:Int
    var totalPopCount:Int
}

extension SplatDatabase{
    func coopEnemyStatus(id:Int) -> AnyPublisher<[CoopEnemyStatus], Error> {
        ValueObservation
            .tracking { db in
                try CoopEnemyStatus.fetchAll(db, SplatDatabaseSQL.enemy_status(accountId: AppUserDefaults.shared.accountId, GroupID: id).request)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}
