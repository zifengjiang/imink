// https://github.com/samuelthomas2774/nxapi/discussions/11
// https://github.com/nintendoapis/splatnet3-types

import Foundation

public struct EmptyParameter: Encodable {}

public protocol SN3PersistedQuery: TargetType {
    associatedtype Parameter: Encodable = EmptyParameter
    
    var parameter: Parameter { get }
    
    static var name: String { get }
}

extension SN3PersistedQuery where Parameter == EmptyParameter {
    public var parameter: EmptyParameter { EmptyParameter() }
}

extension SN3PersistedQuery {
    
    public var baseURL: URL { URL(string: "https://api.lp1.av5ja.srv.nintendo.net")! }
    public var path: String { "/api/graphql" }
    public var method: RequestMethod { .post }
    public var querys: [(String, String?)]? { nil }
    
    public var headers: [String : String]? {
        [
            "Accept-Language": "en-GB"
        ]
    }
    
    public var data: MediaType? {
        return .jsonData(
            GraphQLRequestBody(
                variables: parameter,
                extensions: .init(
                    persistedQuery: .init(
                        version: 1,
                        sha256Hash: "Replace with hash in GraphQLPlugin.swift"
                    )
                )
            )
        )
    }
    
    public var sampleData: Data {
        return try! Data(contentsOf: URL(string: "22")!)
    }
}



// MARK: - LatestBattleHistoriesQuery
    
public struct LatestBattleHistoriesQuery: SN3PersistedQuery {
    public static let name = "LatestBattleHistoriesQuery"
}

extension SN3PersistedQuery where Self == LatestBattleHistoriesQuery {
    public static var latestBattleHistories: LatestBattleHistoriesQuery { .init() }
}

// MARK: RegularBattleHistoriesQuery

public struct RegularBattleHistoriesQuery: SN3PersistedQuery {
    public static let name = "RegularBattleHistoriesQuery"
}

extension SN3PersistedQuery where Self == RegularBattleHistoriesQuery {
    public static var regularBattleHistories: RegularBattleHistoriesQuery { .init() }
}

// MARK: BankaraBattleHistoriesQuery

public struct BankaraBattleHistoriesQuery: SN3PersistedQuery {
    public static let name = "BankaraBattleHistoriesQuery"
}

extension SN3PersistedQuery where Self == BankaraBattleHistoriesQuery {
    public static var bankaraBattleHistories: BankaraBattleHistoriesQuery { .init() }
}

// MARK: PrivateBattleHistoriesQuery

public struct PrivateBattleHistoriesQuery: SN3PersistedQuery {
    public static let name = "PrivateBattleHistoriesQuery"
}

extension SN3PersistedQuery where Self == PrivateBattleHistoriesQuery {
    public static var privateBattleHistories: PrivateBattleHistoriesQuery { .init() }
}

// MARK: XBattleHistoriesQuery

public struct XBattleHistoriesQuery: SN3PersistedQuery {
    public static let name = "XBattleHistoriesQuery"
}

extension SN3PersistedQuery where Self == XBattleHistoriesQuery {
    public static var xBattleHistories: XBattleHistoriesQuery { .init() }
}

// MARK: EventBattleHistoriesQuery

public struct EventBattleHistoriesQuery: SN3PersistedQuery {
    public static let name = "XBattleHistoriesQuery"
}

extension SN3PersistedQuery where Self == EventBattleHistoriesQuery {
    public static var eventBattleHistories: EventBattleHistoriesQuery { .init() }
}

// MARK: CoopHistoryQuery

public struct CoopHistoryQuery: SN3PersistedQuery {
    public static let name = "CoopHistoryQuery"
}

extension SN3PersistedQuery where Self == CoopHistoryQuery {
    public static var coopHistory: CoopHistoryQuery { .init() }
}

// MARK: HistoryRecordQuery

public struct HistoryRecordQuery: SN3PersistedQuery{
    public static let name = "HistoryRecordQuery"
}

extension SN3PersistedQuery where Self == HistoryRecordQuery {
    public static var historyRecord: HistoryRecordQuery { .init() }
}

// MARK: CoopRecordQuery

public struct CoopRecordQuery: SN3PersistedQuery{
    public static let name = "CoopRecordQuery"
}

extension SN3PersistedQuery where Self == CoopRecordQuery {
    public static var coopRecord: CoopRecordQuery { .init() }
}

// MARK: StageRecordQuery

public struct StageRecordQuery: SN3PersistedQuery{
    public static let name = "StageRecordQuery"
}

extension SN3PersistedQuery where Self == StageRecordQuery {
    public static var stageRecord: StageRecordQuery { .init() }
}

// MARK: WeaponRecordQuery

public struct WeaponQuery: SN3PersistedQuery{
    public static let name = "WeaponQuery"
}

extension SN3PersistedQuery where Self == WeaponQuery {
    public static var weaponRecord: WeaponQuery { .init() }
}

// MARK: VSHistoryDetailQuery

public struct VSHistoryDetailQuery: SN3PersistedQuery {
    public static let name = "VsHistoryDetailQuery"
    
    public struct Parameter: Encodable {
        public let vsResultId: String
    }
    
    public var parameter: Parameter
}

extension SN3PersistedQuery where Self == VSHistoryDetailQuery {
    public static func vsHistoryDetail(id: String) -> VSHistoryDetailQuery {
        .init(parameter: .init(vsResultId: id))
    }
}

// MARK: CoopHistoryDetailQuery

public struct CoopHistoryDetailQuery: SN3PersistedQuery {
    public static let name = "CoopHistoryDetailQuery"
    
    public struct Parameter: Encodable {
        public let coopHistoryDetailId: String
    }
    
    public var parameter: Parameter
}

extension SN3PersistedQuery where Self == CoopHistoryDetailQuery {
    public static func coopHistoryDetail(id: String) -> CoopHistoryDetailQuery {
        .init(parameter: .init(coopHistoryDetailId: id))
    }
}

// MARK: FriendListQuery

public struct FriendListQuery: SN3PersistedQuery {
    public static let name = "FriendListQuery"
}

extension SN3PersistedQuery where Self == FriendListQuery {
    public static var friendList: FriendListQuery { .init() }
}
