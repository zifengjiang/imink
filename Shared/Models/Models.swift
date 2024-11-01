import Foundation
import SplatDatabase


extension Coop {
    var gradeName: String?{
        if let afterGrade = afterGrade {
            return "CoopGrade-\(afterGrade)".base64EncodedString
        }
        return nil
    }

    var clear:Bool{
        wave == 3 && rule != "TEAM_CONTEST" || wave == 5 && rule == "TEAM_CONTEST"
    }
}

