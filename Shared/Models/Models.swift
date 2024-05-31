import Foundation
import SwiftUI
import SplatDatabase
import GRDB
import SplatNet3

extension Coop {
    var gradeName: String?{
        if let afterGrade = afterGrade {
            return "CoopGrade-\(afterGrade)".base64EncodedString
        }
        return nil
    }

    var clear:Bool{
        wave == 3 && rule != "TEAM_CONTEST" || wave == 5 && rule == "TEAM_CONTEST"
    }
}

//extension CoopPlayerResult {
//    var specialWeaponName: String {
//        if let specialWeaponId = specialWeaponId {
//            do {
//                return try SplatDatabase.shared.dbQueue.read { getImageName(by: specialWeaponId, db: $0) }
//            }catch{
//                return "DummySpecialWeapon"
//            }
//        }
//        return "DummySpecialWeapon"
//    }
//    
//    var player:Player {
//
//        return try! SplatDatabase.shared.dbQueue.read { db in
//            return try Player.fetchOne(db, sql: "SELECT * FROM player WHERE coopPlayerResultId = ?", arguments: [id])!
//        }
//
//
//    }
//
//    var weapons:[String] {
//        do{
//            return try SplatDatabase.shared.dbQueue.read { db in
//                let rows = try Row.fetchAll(db, sql: """
//                SELECT
//                imageMap.'name'
//                FROM
//                weapon
//                JOIN coopPlayerResult ON coopPlayerResult.id = weapon.coopPlayerResultId
//                JOIN imageMap ON weapon.imageMapId = imageMap.id
//                WHERE
//                coopPlayerResultId = ?
//                ORDER BY
//                weapon.'order'
//                """,arguments: [id])
//                return rows.map { row in
//                    return row["name"]
//                }
//            }
//        }catch {
//            return []
//        }
//    }
//
//}

//extension Player {
//    var uniformName: String {
//        if let uniformId = uniformId {
//            do {
//                return try SplatDatabase.shared.dbQueue.read { getImageName(by: uniformId, db: $0) }
//            }catch{
//                return "DummySpecialWeapon"
//            }
//        }
//        return "DummySpecialWeapon"
//    }
//}

//extension CoopWaveResult {
//    var eventName:String? {
//        if let eventWave = eventWave {
//            do{
//                return try SplatDatabase.shared.dbQueue.read { db in
//                    let row = try Row.fetchOne(db, sql:"SELECT key FROM i18n WHERE id = ?", arguments: [eventWave])
//                    return row?["key"]
//                }
//            }catch{
//                return nil
//            }
//        }
//        return nil
//    }
//
//    var usedSpecialWeapons:[String] {
//        return try! SplatDatabase.shared.dbQueue.read { db in
//            let rows = try Row.fetchAll(db, sql: """
//            SELECT
//                imageMap. 'name'
//            FROM
//                weapon
//                JOIN coopWaveResult ON coopWaveResult.id = weapon.coopWaveResultId
//                JOIN imageMap ON weapon.imageMapId = imageMap.id
//            WHERE
//                coopWaveResultId = ?
//            ORDER BY
//                weapon. 'order'
//            """, arguments: [id])
//            return rows.map { row in
//                return row["name"]
//            }
//        }
//    }
//}
