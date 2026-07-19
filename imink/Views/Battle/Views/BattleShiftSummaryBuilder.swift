import Foundation

enum BattleShiftSummaryBuilder {
    struct BattleInput {
        let judgement: String
        let rule: String
        let stageName: String?
        let weaponName: String?
        let kill: Int
        let assist: Int
        let death: Int
    }

    struct RuleBucket: Equatable {
        let rule: String
        let count: Int
    }

    struct Summary {
        let totalCount: Int
        let winCount: Int
        let loseCount: Int
        let drawCount: Int
        let disconnectCount: Int
        let stageCount: Int
        let weaponCount: Int
        let kill: Int
        let assist: Int
        let death: Int
        let ruleBuckets: [RuleBucket]

        var victoryRate: Double {
            Double(winCount) &/ Double(winCount + loseCount + disconnectCount)
        }

        var kd: Double {
            Double(kill) &/ Double(death)
        }

        var kad: Double {
            Double(kill + assist) &/ Double(death)
        }

        static let empty = Summary(
            totalCount: 0,
            winCount: 0,
            loseCount: 0,
            drawCount: 0,
            disconnectCount: 0,
            stageCount: 0,
            weaponCount: 0,
            kill: 0,
            assist: 0,
            death: 0,
            ruleBuckets: []
        )
    }

    static func build(from battles: [BattleInput]) -> Summary {
        let stageNames = Set(battles.compactMap(\.stageName))
        let weaponNames = Set(battles.compactMap(\.weaponName))
        let ruleCounts = Dictionary(grouping: battles, by: \.rule)
            .map { RuleBucket(rule: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.rule < $1.rule
                }
                return $0.count > $1.count
            }

        return Summary(
            totalCount: battles.count,
            winCount: battles.filter { $0.judgement == "WIN" }.count,
            loseCount: battles.filter { $0.judgement == "LOSE" }.count,
            drawCount: battles.filter { $0.judgement == "DRAW" }.count,
            disconnectCount: battles.filter { $0.judgement == "DEEMED_LOSE" }.count,
            stageCount: stageNames.count,
            weaponCount: weaponNames.count,
            kill: battles.reduce(0) { $0 + $1.kill },
            assist: battles.reduce(0) { $0 + $1.assist },
            death: battles.reduce(0) { $0 + $1.death },
            ruleBuckets: ruleCounts
        )
    }
}
