import Foundation
import SwiftUI
import GRDB
import SplatDatabase

struct CoopShiftCard: Identifiable {
    var id: Int64
    var startTime:Date
    var endTime:Date
    var enemy:Double
    var egg:Double
    var eggAssist:Double
    var rescue:Double
    var rescued:Double
    var stage:String
    var count:Int
    var weapons: [String]{
        return try! SplatDatabase.shared.dbQueue.read { db in
            try String.fetchAll(db, sql:"""
            SELECT DISTINCT
            imageMap.name AS weaponName -- Assuming there's a name column in the imageMap table
            FROM
            weapon
            JOIN coop_view ON weapon.coopId = coop_view.id
            JOIN imageMap ON weapon.imageMapId = imageMap.id
            WHERE
            coop_view.GroupID = ? AND accountId = 2 -- Selecting the latest group
            ORDER BY
            weapon.'order';

        """,arguments: [id])
        }
    }

}


let shift_card_sql = """
SELECT
    coop_view.GroupID as id,
    MIN(playedTime) as startTime,
    MAX(playedTime) as endTime,
    AVG(defeatEnemyCount) as enemy,
    AVG(goldenDeliverCount) as egg,
    AVG(goldenAssistCount) as eggAssist,
    AVG(rescueCount) as rescue,
    AVG(rescuedCount) as rescued,
    imageMap.nameId as stage,
    COUNT(*) as count
FROM
    coop_view
    JOIN coopPlayerResult ON coopPlayerResult.coopId = coop_view.id
    JOIN imageMap ON imageMap.id = coop_view.stageId
WHERE coop_view.GroupID = ? AND coopPlayerResult.'order' = 0 AND coop_view.accountId = 2
"""

extension CoopShiftCard: Codable, FetchableRecord, MutablePersistableRecord {

}

