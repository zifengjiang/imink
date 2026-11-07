import Foundation
import Combine
import GRDB
import SplatDatabase

/// 首页与列表刷新用到的实时统计观察。
///
/// 把 `ValueObservation` 里的 SQL 细节收在数据层，视图模型只消费 Publisher，
/// 避免各页面各自拼「最新班次 / 最新时间」这类查询。
enum RecordStatistics {
    /// 观察某类记录的最新班次 id。
    static func latestGroupIdPublisher(
        kind: SplatRecordKind,
        accountId: Int
    ) -> AnyPublisher<Int?, Never> {
        observation(
            sql: "SELECT MAX(GroupId) FROM \(kind.table)_group_status_view WHERE accountId = ?",
            arguments: [accountId]
        ) { db, sql, arguments in
            try Int.fetchOne(db, sql: sql, arguments: arguments)
        }
    }

    /// 观察某类记录的最新游玩时间。
    static func latestPlayedTimePublisher(
        kind: SplatRecordKind,
        accountId: Int
    ) -> AnyPublisher<Date?, Never> {
        observation(
            sql: "SELECT MAX(playedTime) FROM \(kind.table) WHERE accountId = ?",
            arguments: [accountId]
        ) { db, sql, arguments in
            try Date.fetchOne(db, sql: sql, arguments: arguments)
        }
    }

    /// 观察某类记录的总条数（不含回收站）。
    static func totalCountPublisher(kind: SplatRecordKind) -> AnyPublisher<Int, Error> {
        ValueObservation
            .tracking { db in
                switch kind {
                case .coop:
                    return try Coop.filter(sql: "isDeleted = 0").fetchCount(db)
                case .battle:
                    return try Battle.filter(sql: "isDeleted = 0").fetchCount(db)
                }
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    private static func observation<T>(
        sql: String,
        arguments: StatementArguments,
        fetch: @escaping (Database, String, StatementArguments) throws -> T?
    ) -> AnyPublisher<T?, Never> {
        ValueObservation
            .tracking { db in
                try fetch(db, sql, arguments)
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
            .catch { error -> Just<T?> in
                logError(error)
                return Just<T?>(nil)
            }
            .eraseToAnyPublisher()
    }
}
