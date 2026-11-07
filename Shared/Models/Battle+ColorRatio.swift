import Foundation
import SwiftUI
import UIKit
import SplatDatabase

extension Battle {
    func getColorRatioText()->([Color?],[Double?],[String?]){
        var colors:[Color?] = self.getColors()
        var ratios:[Double?] = []
        var texts:[String?] = []
        colors.append(teams.first{$0.order == 1}?.color.toColor())
        if let rule = BattleRule(rawValue: rule), rule == .triColor{
            colors.append(teams.first{$0.order == 2}?.color.toColor())
            colors.append(teams.first{$0.order == 3}?.color.toColor())
        }else{
            colors.append(nil)
            colors.append(teams.first{$0.order == 2}?.color.toColor())
        }

        if let rule = BattleRule(rawValue: rule), rule == .triColor || rule == .turfWar{
            ratios.append(teams.first{$0.order == 1}?.paintRatio)
            texts.append("\((teams.first{$0.order == 1}?.paintRatio ?? 0)*100)%")
            if rule == .triColor{
                ratios.append(teams.first{$0.order == 2}?.paintRatio)
                texts.append("\((teams.first{$0.order == 2}?.paintRatio ?? 0)*100)%")
                ratios.append(teams.first{$0.order == 3}?.paintRatio)
                texts.append("\((teams.first{$0.order == 3}?.paintRatio ?? 0)*100)%")
            }else{
                ratios.append(nil)
                texts.append(nil)
                ratios.append(teams.first{$0.order == 2}?.paintRatio)
                texts.append("\((teams.first{$0.order == 2}?.paintRatio ?? 0)*100)%")
            }
        }else if let myTeam = teams.first(where: {$0.order == 1}), let otherTeam = teams.first(where: {$0.order == 2}),let leftScore = myTeam.score,let rightScore = otherTeam.score{
            ratios.append(Double(leftScore)/Double(leftScore+rightScore))
            texts.append("\(leftScore)计数")
            ratios.append(nil)
            texts.append(nil)
            ratios.append(Double(rightScore)/Double(leftScore+rightScore))
            texts.append("\(rightScore)计数")
        }

        while colors.count < 3{
            colors.append(nil)
        }
        while ratios.count < 3{
            ratios.append(nil)
        }
        while texts.count < 3{
            texts.append(nil)
        }
        return (colors, ratios, texts)
    }

    func getColors()->[Color?]{
        var colors:[Color?] = []
        colors.append(teams.first{$0.order == 1}?.color.toColor())
        if let rule = BattleRule(rawValue: rule), rule == .triColor{
            colors.append(teams.first{$0.order == 2}?.color.toColor())
            colors.append(teams.first{$0.order == 3}?.color.toColor())
        }else{
            colors.append(nil)
            colors.append(teams.first{$0.order == 2}?.color.toColor())
        }
        return colors
    }
}
