import Foundation

/// 复用的 `DateFormatter` 缓存。
///
/// `DateFormatter` 创建开销较大，列表渲染时逐帧新建（原实现）会带来明显浪费，
/// 因此按格式集中缓存；本项目的时间展示都使用设备当前时区。
enum DateFormat {
    static let hourMinute = make("HH:mm")
    static let monthDay = make("MM/dd")
    static let monthDayHourMinute = make("MM/dd HH:mm")
    static let yearMonthDayHourMinute = make("yyyy MM/dd HH:mm")
    static let yearMonthDayHourMinuteSecond = make("yyyy MM/dd HH:mm:ss")
    static let compactMinute = make("yyyyMMddHHmm")
    static let isoUTC = make("yyyy-MM-dd'T'HH:mm:ssZ")

    static func make(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter
    }

    /// 同一年内只显示月/日，跨年时补上年份。
    static func dayAndTime(for date: Date) -> DateFormatter {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
            ? monthDayHourMinute
            : yearMonthDayHourMinute
    }
}

extension Date {
    /// 记录列表中的时间展示：今天只显示时分，当年不显示年份。
    func toPlayedTimeString(full: Bool = false) -> String {
        if full {
            return DateFormat.yearMonthDayHourMinuteSecond.string(from: self)
        }
        if Calendar.current.isDateInToday(self) {
            return DateFormat.hourMinute.string(from: self)
        }
        return DateFormat.dayAndTime(for: self).string(from: self)
    }

    /// 班次卡片 / 详情页的时间跨度：`MM/dd HH:mm - MM/dd HH:mm`，跨年时补上年份。
    func toShiftTimeSpanString(end: Date) -> String {
        let formatter = DateFormat.dayAndTime(for: self)
        return "\(formatter.string(from: self)) - \(formatter.string(from: end))"
    }
}
