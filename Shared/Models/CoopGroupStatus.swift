import GRDB
import SplatDatabase
import Foundation
import Combine

struct CoopGroupStatus: FetchableRecord, Decodable {
    var accountId: Int
    var groupId: Int
    var rule: String
    var startTime: Date
    var endTime: Date
    var avgDefeatEnemyCount: Double
    var avgDeliverCount: Double
    var avgGoldenAssistCount: Double
    var avgGoldenDeliverCount: Double
    var avgRescueCount: Double
    var avgRescuedCount: Double
    var highestScore: Int?
    var highestEgg: Int
    var count: Int
}

extension SplatDatabase{
    func coopGroupStatus(id:Int) -> AnyPublisher<CoopGroupStatus?, Error> {
        ValueObservation
            .tracking { db in
                try CoopGroupStatus.fetchOne(db, SplatDatabaseSQL.group_status(accountId: AppUserDefaults.shared.accountId, GroupID: id).request)
            }
            .publisher(in: dbQueue)
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
            .publisher(in: dbQueue)
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
            .publisher(in: dbQueue)
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
            .publisher(in: dbQueue)
            .eraseToAnyPublisher()
    }
}
