//
//  BattleListRowInfo.swift
//  imink
//
//  Created by 姜锋 on 10/6/24.
//

import Foundation
import SplatDatabase
import GRDB
import Combine

struct BattleListRowInfo:Codable, FetchableRecord, PersistableRecord{
    var id: Int64
    var mode:BattleMode
    var rule:BattleRule
    var judgement:Judgement
    var stage:String
    var weapon:PackableNumbers
    var kill:Int
    var assist:Int
    var death:Int
    var udemae:String?
    var point:Int
    var playedTime:Date
    var earnedUdemaePoint:Int?
    var species:Bool
    var knockout:JudgementKnockout?


    // MARK: computed
    var ratios:[Double] = []
    var colors:[PackableNumbers] = []
    var scores:[Int64] = []
    var _weapon:Player.Weapon? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case mode
        case rule
        case judgement
        case stage
        case weapon
        case kill
        case assist
        case death
        case udemae
        case point
        case playedTime
        case earnedUdemaePoint
        case species
        case knockout
    }
}

extension BattleListRowInfo: PreComputable{

    static func create(from db: Database, identifier: (Int,Filter,Int,Int)) throws ->[BattleListRowInfo]{
        let (accountId,filter, limit, offset) = identifier
        let rows = try Row.fetchAll(db, filter.buildBattleQuery(limit:limit, offset:offset))
        return rows.compactMap{ row in
            var info = try! BattleListRowInfo(row: row)
            let computed = try! Row.fetchAll(db, sql: """
                SELECT 
                vsTeam.color,
                vsTeam.paintRatio as ratio,
                vsTeam.score as score
                FROM vsTeam
                JOIN battle on battle.id = vsTeam.battleId
                WHERE accountId = \(accountId) AND battleId = \(info.id)
                ORDER by vsTeam.`order`

        """)
            info.ratios = computed.compactMap{
                $0["ratio"] as? Double
            }

            info.colors = computed.compactMap{
                return PackableNumbers.fromDatabaseValue($0["color"])
            }

            info.scores = computed.compactMap{
                $0["score"] as? Int64
            }

            info._weapon = Player.Weapon(with: info.weapon, db: db)

            return info
        }


    }


}

func battles(filter:Filter = Filter(), limit:Int = 30, _ offset: Int = 0) async -> [BattleListRowInfo] {
    return try! await SplatDatabase.shared.dbQueue.read { db in
//        try Row.fetchAll(db, filter.buildBattleQuery(limit:limit, offset:offset))
//            .compactMap { row in
//                try! BattleListRowInfo(row: row)
//            }
        try BattleListRowInfo.create(from: db, identifier: (AppUserDefaults.shared.accountId, filter, limit, offset))
    }
}




extension Filter {
    func buildBattleQuery(accountId: Int = AppUserDefaults.shared.accountId, limit:Int, offset:Int) -> SQLRequest<Row> {
        var conditions: [String] = []
        var arguments: [DatabaseValueConvertible] = []

        if !modes.isEmpty{
            let array = Array(modes)
            let rulePlaceholders = array.map { _ in "?" }.joined(separator: ", ")
            conditions.append("battle.mode IN (\(rulePlaceholders))")
            arguments.append(contentsOf: array)
        }

        let whereClause = conditions.isEmpty ? "1" : conditions.joined(separator: " AND ")
        let sql = """
                SELECT 
                    battle.id,
                    battle.mode,
                    battle.rule,
                    battle.judgement,
                    battle.udemae,
                    stage.nameId AS stage,
                    player.weapon AS weapon,
                    COALESCE(player.kill,0) as `kill`,
                    COALESCE(player.assist,0) as assist,
                    COALESCE(player.death,0) as death,
                    player.paint AS point,
                    battle.playedTime as playedTime,
                    battle.earnedUdemaePoint,
                    battle.knockout,
                    player.species
                FROM 
                    battle
                LEFT JOIN 
                    vsTeam ON vsTeam.battleId = battle.id -- 获取团队涂装比率和颜色信息
                JOIN 
                    player ON vsTeam.id = player.vsTeamId -- 假设 battle 和 player 通过 vsTeamId 关联
                JOIN 
                    imageMap AS stage ON battle.stageId = stage.id
                WHERE 
                    \(whereClause) and battle.accountId = \(accountId) and player.isMyself = 1 -- 过滤当前用户的 accountId
                ORDER BY battle.playedTime DESC
                LIMIT \(limit) OFFSET \(offset);
                """
        return SQLRequest<Row>(sql: sql, arguments: StatementArguments(arguments))
    }
}
