import Foundation
import SwiftUI
import SplatDatabase
import SwiftyJSON
import SplatNet3API
import IndicatorsKit


func performTaskEveryHourSince(startDate: Date, task: @escaping (Date) async throws -> Void, progress: @escaping (Double) -> Void) async {
    let calendar = Calendar.current
    var currentDate = startDate
    
    let totalDays = calendar.dateComponents([.day], from: startDate, to: Date()).day!

    while currentDate <= Date() {
        let startOfHour = calendar.date(bySettingHour: calendar.component(.hour, from: currentDate), minute: 0, second: 0, of: currentDate)!
        let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour)!

        for hour in stride(from: startOfHour, to: endOfHour, by: 3600) {
            do {
                try await task(hour)
                break
            } catch {
                    // If task throws an error, try again next hour
                print("Task failed at hour \(hour), retrying next hour")
            }
        }

            // Move to next day
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) {
            currentDate = nextDay
            progress(Double(calendar.dateComponents([.day], from: startDate, to: currentDate).day!) / Double(totalDays))
        } else {
            break
        }
    }
}

func fetchHistorySchedules() async {
    let indicatorId = UUID().uuidString
    Indicators.shared.display(.init(id: indicatorId, title: "正在获取历史日程", progress: 0))
    await performTaskEveryHourSince(startDate: getCoopEarliestPlayedTime()) { date in
        let api = Splatoon3InkAPI.historySchedule(date)
        let (data, _) = try await URLSession.shared.data(for: api.request)
        let json = try JSON(data:data)
        try await SplatDatabase.shared.dbQueue.write { db in
            try insertSchedules(json: json, db: db)
        }
    } progress: { date in
        Indicators.shared.updateProgress(for: indicatorId, progress: date)
        if date == 1.0 {
            Indicators.shared.dismiss(with: indicatorId)
        }
    }
}


extension Schedule.Mode {
    func localized(open:Bool = false) -> String {
        switch self {
        case .regular:
            return "VnNNb2RlLTE=".localizedFromSplatNet
        case .bankara:
            if open{
                return "VnNNb2RlLTUx".localizedFromSplatNet
            }else{
                return "VnNNb2RlLTI=".localizedFromSplatNet
            }
        case .x:
            return "VnNNb2RlLTM=".localizedFromSplatNet
        case .event:
            return "VnNNb2RlLTQ=".localizedFromSplatNet
        case .fest:
            if open{
                return "VnNNb2RlLTY=".localizedFromSplatNet
            }else{
                return "VnNNb2RlLTc=".localizedFromSplatNet
            }
        case .salmonRun:
            return "鲑鱼跑".localized
        }
    }

    var icon:Image {
        switch self {
        case .regular:
            return Image(.regular)
        case .bankara:
            return Image(.anarchy)
        case .x:
            return Image(.xBattle)
        case .event:
            return Image(.event)
        case .fest:
            return Image(.event)
        case .salmonRun:
            return Image(.salmonRun)
        }
    }
}

extension Schedule.Rule {
    var localized: String {
        switch self {
        case .turfWar:
            return "VnNNb2RlLTE=".localizedFromSplatNet
        case .splatZones:
            return "VnNSdWxlLTE=".localizedFromSplatNet
        case .towerControl:
            return "VnNSdWxlLTI=".localizedFromSplatNet
        case .rainmaker:
            return "VnNSdWxlLTM=".localizedFromSplatNet
        case .clamBlitz:
            return "VnNSdWxlLTQ=".localizedFromSplatNet
        case .triColor:
            return "VnNSdWxlLTU=".localizedFromSplatNet
        case .salmonRun:
            return "鲑鱼跑".localized
        case .bigRun:
            return "大型跑".localized
        case .teamContest:
            return "团队打工竞赛".localized
        }
    }

    var icon:Image {
        switch self {
        case .turfWar:
            return Image(.turfWar)
        case .splatZones:
            return Image(.splatZones)
        case .towerControl:
            return Image(.towerControl)
        case .rainmaker:
            return Image(.rainmaker)
        case .clamBlitz:
            return Image(.clamBlitz)
        case .triColor:
            return Image(.turfWar)
        case .salmonRun:
            return Image(.salmonRun)
        case .bigRun:
            return Image(.bigrun)
        case .teamContest:
            return Image(.teamContest)
        }
    }
}

extension Schedule {
    var formattedBattleTime: String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()

            // 日期和时间格式化器
        dateFormatter.dateFormat = "HH:mm"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MM/dd"

            // 当前时间
        let now = Date()

            // 获取开始时间和结束时间的天部分
        let startDay = calendar.startOfDay(for: startTime)
        let endDay = calendar.startOfDay(for: endTime)
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)!

        switch (startDay, endDay) {
        case (today, today):
            return "\(dateFormatter.string(from: startTime)) - \(dateFormatter.string(from: endTime))"
        case (today, tomorrow):
            return "\(dateFormatter.string(from: startTime)) - 明天 \(dateFormatter.string(from: endTime))"
        case (tomorrow, tomorrow):
            return "明天 \(dateFormatter.string(from: startTime)) - \(dateFormatter.string(from: endTime))"
        case (tomorrow, dayAfterTomorrow):
            return "明天 \(dateFormatter.string(from: startTime)) - 后天 \(dateFormatter.string(from: endTime))"
        case (dayAfterTomorrow, dayAfterTomorrow):
            return "后天 \(dateFormatter.string(from: startTime)) - \(dateFormatter.string(from: endTime))"
        default:
            let startDateString = dayFormatter.string(from: startTime)
            let endDateString = dateFormatter.string(from: endTime)
            return "\(startDateString) \(dateFormatter.string(from: startTime)) - \(endDateString)"
        }
    }

    var formattedSalmonRunTime: String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd HH:mm"
        return "\(dateFormatter.string(from: startTime)) - \(dateFormatter.string(from: endTime))"
    }
}

extension Schedule{
    var openStage: [ImageMap] {
        if rule2 != nil{
            return [_stage[2], _stage[3]]
        }
        return []
    }

    var challengeStage: [ImageMap] {
        if rule2 != nil{
            return [_stage[0], _stage[1]]
        }
        return []
    }
}
