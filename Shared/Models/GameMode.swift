import Foundation
import SwiftUI

enum GameMode :CaseIterable {
    case regular
    case x
    case event
    case bankara
    case salmonRun
}

extension GameMode {
    var image:Image {
        switch self {
        case .regular:
            return Image(.badgeUdemaeLv00)
        case .x:
            return Image(.badgeUdemaeLv01)
        case .event:
            return Image(.badgeUdemaeLv02)
        case .bankara:
            return Image(.badgeMissionLv01)
        case .salmonRun:
            return Image(.badgeMissionLv03)
        }
    }
}

extension GameMode: Identifiable {
    var id: Int {
        switch self {
        case .regular:
            return 0
        case .x:
            return 1
        case .event:
            return 2
        case .bankara:
            return 3
        case .salmonRun:
            return 4
        }
    }

    var name: String {
        switch self {
        case .regular:
            return "一般比赛"
        case .x:
            return "X比赛"
        case .event:
            return "活动比赛"
        case .bankara:
            return "蛮颓比赛"
        case .salmonRun:
            return "鲑鱼跑"
        }
    }
}
