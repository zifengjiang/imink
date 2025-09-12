//
//  FriendList.swift
//  imink
//
//  Created by AI Assistant
//

import Foundation

// MARK: - FriendList Models

public struct FriendListResult: Codable {
    public let data: Data
    
    public struct Data: Codable {
        public var currentFest: CurrentFest?
        public var friends: Friends?
        
        public struct CurrentFest: Codable {
            public var id: String
            public var state: String
            public var teams: [FestTeam]?
            
            public struct FestTeam: Codable {
                public var id: String
                public var color: Color
                
                public struct Color: Codable {
                    public var r: Float
                    public var g: Float
                    public var b: Float
                    public var a: Float
                }
            }
        }
        
        public struct Friends: Codable {
            public var nodes: [Node]?
            
            public struct Node: Codable, Equatable {
                public var id: String
                public var coopRule: String?
                public var isLocked: Bool?
                public var isVcEnabled: Bool?
                public var nickname: String
                public var onlineState: String
                public var playerName: String?
                public var userIcon: UserIcon?
                public var vsMode: VsMode?
                public var isFavorite: Bool?
                
                public struct UserIcon: Codable, Equatable {
                    public var height: Int
                    public var url: String
                    public var width: Int
                }
            }
        }
    }
}

public struct VsMode: Codable, Equatable {
    public var id: String
    public var mode: String
}

// MARK: - Friend Online States

public enum FriendOnlineState: String, CaseIterable {
    case OFFLINE = "OFFLINE"
    case ONLINE = "ONLINE"
    case VS_MODE_MATCHING = "VS_MODE_MATCHING"
    case COOP_MODE_MATCHING = "COOP_MODE_MATCHING"
    case MINI_GAME_PLAYING = "MINI_GAME_PLAYING"
    case VS_MODE_FIGHTING = "VS_MODE_FIGHTING"
    case COOP_MODE_FIGHTING = "COOP_MODE_FIGHTING"
}
