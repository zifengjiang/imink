//
//  BattleListRowModel.swift
//  imink
//
//  Created by 姜锋 on 10/6/24.
//

import Foundation

struct BattleListRowModel:Identifiable {
    let isBattle: Bool
    var battle: BattleListRowInfo?
    var card: CoopGroupStatus?

    var id: String {
        if isBattle {
            return "detail-\(battle!.id)"
        }
        return "card-\(card!.startTime)-\(card!.count)"
    }

}
