import Foundation
import SwiftUI

enum CoopRule: String, Codable, Hashable, CaseIterable {
    case ALL = "ALL_RULE"
    case REGULAR = "REGULAR"
    case BIG_RUN = "BIG_RUN"
    case TEAM_CONTEST = "TEAM_CONTEST"
}

extension CoopRule{
    var icon:Image{
        switch self {
        case .REGULAR, .ALL:
            return Image(.salmonRun)
        case .BIG_RUN:
            return Image(.coopBigrun)
        case .TEAM_CONTEST:
            return Image(.coopTeamContest)

        }
    }

    var name:String{
        switch self {
        case .REGULAR:
            return "鲑鱼跑"
        case .BIG_RUN:
            return "大型跑"
        case .TEAM_CONTEST:
            return "团队打工竞赛"
        case .ALL:
            return "全部打工"
        }
    }
}
