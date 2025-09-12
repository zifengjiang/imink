//
//  FriendStyles.swift
//  imink
//
//  Created by AI Assistant
//

import SwiftUI

// MARK: - Friend Colors and Styles

extension Color {
    // 好友在线状态颜色
    static let friendOnline = Color.green
    static let friendPlaying = Color.orange
    static let friendOffline = Color.gray
}

// MARK: - Friend State Functions

/// 根据好友状态获取边框颜色
func getFriendColor(friend: FriendListResult.Data.Friends.Node) -> Color {
    switch friend.onlineState {
    case FriendOnlineState.VS_MODE_FIGHTING.rawValue,
         FriendOnlineState.COOP_MODE_FIGHTING.rawValue,
         FriendOnlineState.MINI_GAME_PLAYING.rawValue:
        return .friendPlaying
    case FriendOnlineState.VS_MODE_MATCHING.rawValue,
         FriendOnlineState.COOP_MODE_MATCHING.rawValue,
         FriendOnlineState.ONLINE.rawValue:
        return .friendOnline
    case FriendOnlineState.OFFLINE.rawValue:
        return .friendOffline
    default:
        return .friendOffline
    }
}

/// 根据好友状态获取状态图标
func getStateIcon(friend: FriendListResult.Data.Friends.Node) -> Image {
    switch friend.onlineState {
    case FriendOnlineState.VS_MODE_FIGHTING.rawValue:
        return getVsModeIcon(mode: friend.vsMode?.id ?? "regular")
    case FriendOnlineState.COOP_MODE_FIGHTING.rawValue:
        return getCoopRuleIcon(rule: CoopRule(rawValue: friend.coopRule ?? "") ?? CoopRule.REGULAR)
    case FriendOnlineState.MINI_GAME_PLAYING.rawValue:
        return Image(systemName: "gamecontroller")
    case FriendOnlineState.VS_MODE_MATCHING.rawValue,
         FriendOnlineState.COOP_MODE_MATCHING.rawValue,
         FriendOnlineState.ONLINE.rawValue:
        return Image(systemName: "person.circle.fill")
    case FriendOnlineState.OFFLINE.rawValue:
        return Image(systemName: "person.slash")
    default:
        return Image(systemName: "person.slash")
    }
}

/// 根据对战模式ID获取模式图标
func getVsModeIcon(mode: String) -> Image {
    switch mode {
    case "VnNNb2RlLTE=": // Regular
        return Image(systemName: "gamecontroller")
    case "VnNNb2RlLTI=", "VnNNb2RlLTUx": // Anarchy
        return Image(systemName: "flame")
    case "VnNNb2RlLTM=": // X Battle
        return Image(systemName: "xmark.circle")
    case "VnNNb2RlLTQ=": // Challenge
        return Image(systemName: "trophy")
    case "VnNNb2RlLTU=": // Private
        return Image(systemName: "lock")
    default:
        return Image(systemName: "gamecontroller")
    }
}

/// 根据打工模式获取图标
func getCoopRuleIcon(rule: CoopRule) -> Image {
    switch rule {
    case .REGULAR:
        return Image(systemName: "fish")
    case .BIG_RUN:
        return Image(systemName: "fish.circle")
    case .TEAM_CONTEST:
        return Image(systemName: "trophy.circle")
    case .ALL:
        return Image(systemName: "trophy.circle")
    }
}
