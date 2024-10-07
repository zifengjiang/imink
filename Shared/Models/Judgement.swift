import Foundation
import SwiftUI

enum Judgement: String, Codable {
    case WIN = "WIN"
    case LOSE = "LOSE"
    case EXEMPTED_LOSE = "EXEMPTED_LOSE"
    case DEEMED_LOSE = "DEEMED_LOSE"
    case DRAW = "DRAW"

    var name:String{
        switch self {
        case .WIN:
            return rawValue+"!"
        case .LOSE,.EXEMPTED_LOSE,.DEEMED_LOSE:
            return Judgement.LOSE.rawValue+"..."
        case .DRAW:
            return rawValue
        }
    }
    var color:Color{
        switch self {
        case .WIN:
            return Color.spLightGreen
        default:
            return Color.spPink
        }
    }
}


enum JudgementKnockout: String, Codable {
    case NEITHER = "NEITHER"
    case WIN = "WIN"
    case LOSE = "LOSE"
}
