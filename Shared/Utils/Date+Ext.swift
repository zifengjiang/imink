import Foundation
import SwiftUI
extension Date {


  func toPlayedTimeString(full:Bool = false) -> String {
    let calendar = Calendar.current
    let now = Date()

    let formatter = DateFormatter()

    if calendar.isDateInToday(self) {
      // 如果是当天，只显示小时和分钟
      formatter.dateFormat = "HH:mm"
    } else if calendar.isDate(self, equalTo: now, toGranularity: .year) {
      // 如果是当年，不显示年份
      formatter.dateFormat = "MM/dd HH:mm"
    } else {
      // 其他情况，显示完整日期
      formatter.dateFormat = "yyyy MM/dd HH:mm"
    }
    if full{
      formatter.dateFormat = "yyyy MM/dd HH:mm"
    }
    return formatter.string(from: self)
  }
}
