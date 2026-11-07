import Foundation
import Combine
import GRDB
import SplatDatabase

/// 赛程 / 日程查询。
enum ScheduleRepository {
    /// 与指定时间相关的日程（含正在进行中的），按开始时间升序。
    static func upcoming(at date: Date = Date()) -> AnyPublisher<[Schedule], Error> {
        Schedule.fetchAll(identifier: SQLRequest(
            sql: """
                SELECT * FROM schedule
                WHERE startTime >= ? OR (startTime <= ? AND endTime >= ?)
                ORDER BY startTime ASC
                """,
            arguments: [date, date, date]
        ))
    }
}
