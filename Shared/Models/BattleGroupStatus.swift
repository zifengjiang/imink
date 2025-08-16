//
//  BattleGroupStatus.swift
//  imink
//
//  Created by 姜锋 on 10/4/24.
//

import Foundation
import GRDB
import SplatDatabase
import Combine

struct BattleGroupStatus:FetchableRecord, Codable {
    let accountId: Int64
    let groupId: Int64
    let mode: String

        /// 视图中的 startTime / endTime 保持 UTC 展示，这里解析为 Date（可能为 nil）
    let startTime: Date
    let endTime: Date

    let count: Int
    let winCount: Int
    let loseCount: Int
    let drawCount: Int
    let disconnectCount: Int
    let koWinCount: Int
    let koLoseCount: Int

    let avgDuration: Double?         // AVG() -> REAL
    let maxMyLeaguePower: Int?       // MAX() of INTEGER -> 可空 Int
    let maxLastXPower: Double?       // MAX() of DOUBLE -> Double?
    let maxEntireXPower: Double?
    let festContribution: Int?       // SUM() 可能为 0 或 NULL，这里用 Int?
    let festJewel: Int?
    let avgMyFestPower: Double?

        // 我方个人统计（整组求和）
    let kill: Int
    let death: Int
    let assist: Int
    let special: Int

    // victory rate
    var victoryRate: Double {
        Double(winCount) &/ Double(winCount + loseCount + disconnectCount)
    }

    var kd: Double {
        Double(kill) &/ Double(death)
    }

    var kad: Double {
        Double(kill + assist) &/ Double(death)
    }
}

extension BattleGroupStatus: PreComputable{
    static func create(from db: Database, identifier: (Int, Int)) throws -> BattleGroupStatus? {
        let (groupId, accountId) = identifier
        if let status = try? BattleGroupStatus.fetchOne(db, sql: "SELECT * FROM battle_group_status_view WHERE GroupID = ? AND accountId = ?", arguments: [groupId, accountId]){
            return status
        }
        return nil
    }

    static func create(from db: Database, identifier: (Int, Int)) throws -> [BattleGroupStatus] {
        let (accountId, offset) = identifier
        if let statuses = try? BattleGroupStatus.fetchAll(db, sql: "SELECT * FROM battle_group_status_view WHERE accountId = ? ORDER BY GroupID DESC LIMIT 10 OFFSET ?", arguments: [accountId, offset]){
            return statuses
        }
        return []
    }
}

extension BattleGroupStatus{
    static let defaultValue = BattleGroupStatus(
        accountId: 0,
        groupId: 0,
        mode: "",
        startTime: Date(),
        endTime: Date(),
        count: 0,
        winCount: 0,
        loseCount: 0,
        drawCount: 0,
        disconnectCount: 0,
        koWinCount: 0,
        koLoseCount: 0,
        avgDuration: nil,
        maxMyLeaguePower: nil,
        maxLastXPower: nil,
        maxEntireXPower: nil,
        festContribution: nil,
        festJewel: nil,
        avgMyFestPower: nil,
        kill: 0,
        death: 0,
        assist: 0,
        special: 0
    )
    
}
