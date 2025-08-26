//
//  BattleListRowView.swift
//  imink
//
//  Created by 姜锋 on 10/6/24.
//

import SwiftUI
import SplatDatabase

func convertToPercentages(intArray: [Int64]) -> [Double] {
        // 计算数组的总和
    let total = intArray.reduce(0, +)

        // 如果总和为 0，返回一个全为 0 的数组，防止除以 0
    guard total > 0 else {
        return Array(repeating: 0.0, count: intArray.count)
    }

        // 转换为占比数组
    return intArray.map { Double($0) / Double(total) }
}

func convertToPercentages(doubleArray: [Double]) -> [Double] {
        // 计算数组的总和
    let total = doubleArray.reduce(0, +)

        // 如果总和为 0，返回一个全为 0 的数组，防止除以 0
    guard total > 0 else {
        return Array(repeating: 0.0, count: doubleArray.count)
    }

        // 转换为占比数组
    return doubleArray.map { Double($0) / Double(total) }
}

func getRatio(scores:[Int64], ratios:[Double],count:Int) -> [Double] {
    if ratios.isEmpty && scores.isEmpty{
        return Array(repeating: 0.0, count: count)
    }

    if ratios.isEmpty{
        return convertToPercentages(intArray: scores)
    }else{
        return convertToPercentages(doubleArray: ratios)
    }
}

struct BattleListRowView: View {
    let row: BattleListRowModel

    var body: some View {
        if row.isBattle, let battle = row.battle {
            BattleListDetailItemView(detail: battle)
        } else if let card = row.card {
            BattleListShiftCardView(status: card)
        } else {
            EmptyView()
        }
    }
}

//#Preview {
//    BattleListRowView()
//}
