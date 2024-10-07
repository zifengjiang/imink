//
//  BattleGroupStatus.swift
//  imink
//
//  Created by 姜锋 on 10/4/24.
//

import Foundation
import GRDB
import SplatDatabase

struct BattleGroupStatus:FetchableRecord, Codable {
    var victory: Int
    var defeat: Int
    var disconnect: Int
    var kill: Int
    var assist: Int
    var death: Int
    var lastPlayTime: Date?

    // victory rate
    var victoryRate: Double {
        Double(victory) &/ Double(victory + defeat + disconnect)
    }

    var kd: Double {
        Double(kill) &/ Double(death)
    }

    var kad: Double {
        Double(kill + assist) &/ Double(death)
    }
}

extension BattleGroupStatus{
    static let defaultValue = BattleGroupStatus(victory: 0, defeat: 0, disconnect: 0, kill: 0, assist: 0, death: 0)
}

extension BattleGroupStatus: PreComputable{
    static func create(from db: Database, identifier: Int) throws -> BattleGroupStatus?{
        let accountId = identifier
        if let status = try? BattleGroupStatus.fetchOne(db, sql: BattleGroupStatus.SQL, arguments: [accountId, accountId]){
            return status
        }
        return nil
    }

}

extension BattleGroupStatus{
    static let SQL = """
    WITH latest_date AS (
    SELECT MAX(playedTime) AS max_played_date
    FROM battle
    WHERE accountId = ?
    ),
    battle_stats AS (
    SELECT 
        b.id AS battleId,
        CASE 
            WHEN b.judgement IN ('WIN') THEN 1 
            ELSE 0 
        END AS victory,
        CASE 
            WHEN b.judgement IN ('LOSE','DRAW','EXEMPTED_LOSE') THEN 1 
            ELSE 0 
        END AS defeat,
        CASE 
            WHEN b.judgement = 'DEEMED_LOSE' THEN 1 
            ELSE 0 
        END AS disconnect,
        COALESCE(SUM(p.kill), 0) AS total_kill,
        COALESCE(SUM(p.assist), 0) AS total_assist,
        COALESCE(SUM(p.death), 0) AS total_death,
        ld.max_played_date as latest_date
    FROM battle b
    JOIN vsTeam vt ON vt.battleId = b.id
    JOIN player p ON p.vsTeamId = vt.id
    JOIN latest_date ld ON DATE(b.playedTime) = DATE(ld.max_played_date)
    WHERE b.accountId = ? AND p.isMyself = 1
    GROUP BY b.id, b.judgement
    )
    SELECT 
    COALESCE(SUM(victory),0) AS victory,
    COALESCE(SUM(defeat),0) AS defeat,
    COALESCE(SUM(disconnect),0) AS disconnect,
    COALESCE(SUM(total_kill),0) AS `kill`,
    COALESCE(SUM(total_assist),0) AS assist,
    COALESCE(SUM(total_death),0) AS death,
    latest_date as lastPlayTime
    FROM battle_stats;
    """
}
