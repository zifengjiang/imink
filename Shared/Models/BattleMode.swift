import Foundation
import SwiftUI
import SplatDatabase



enum BattleMode:String,CaseIterable,Codable{
    case regular = "REGULAR"
    case anarchy = "BANKARA"
    case xMatch = "XMATCH"
    case league = "LEAGUE"
    case privateMatch =  "PRIVATE"
    case fest = "FEST"

//    init(rawValue: String) {
//        switch rawValue {
//        case "VnNNb2RlLTE=", "VnNNb2RlLTY=", "VnNNb2RlLTc=", "VnNNb2RlLTg=":
//            self = .regular
//        case "VnNNb2RlLTI=","VnNNb2RlLTUx":
//            self = .anarchy
//        case "VnNNb2RlLTM=":
//            self = .xMatch
//        case "VnNNb2RlLTQ=":
//            self = .league
//        case "VnNNb2RlLTU=":
//            self = .privateMatch
//        default:
//            self = .regular
//        }
//    }
    var replacement:String{self.rawValue}


    var icon:Image{
        switch self {
        case .regular, .fest:
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

    var color:Color{
        switch self {
        case .regular, .fest:
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
