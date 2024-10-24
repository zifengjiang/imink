import Foundation
import SwiftUI
import SplatDatabase



enum BattleMode:String,CaseIterable,Codable{
    case all = "ALL"
    case regular = "REGULAR"
    case anarchy = "BANKARA"
    case xMatch = "XMATCH"
    case league = "LEAGUE"
    case privateMatch =  "PRIVATE"
    case fest = "FEST"

    var replacement:String{self.rawValue}


    var icon:Image{
        switch self {
        case .regular, .fest, .all:
            return Image(.turfWar)
        case .anarchy:
            return Image(.anarchy)
        case .xMatch:
            return  Image(.xBattle)
        case .league:
            return Image(.event)
        case .privateMatch:
            return Image(.private)

        }
    }

    var name:String{
        rawValue.localized
    }


    var color:Color{
        switch self {
        case .regular, .fest, .all:
            return Color.spLightGreen
        case .anarchy:
            return Color.spOrange
        case .xMatch:
            return Color.xBattleTheme
        case .league:
            return Color.spPink
        case .privateMatch:
            return Color.spPurple
        }
    }
}

extension Battle {
    var battleMode: BattleMode {
        BattleMode(rawValue: mode) ?? .regular
    }
}
