//
//  ScheduleSubscription.swift
//  imink
//
//  Created by Assistant on 2024/12/26.
//

import Foundation

// MARK: - 订阅类型枚举
enum ScheduleType: String, Codable, CaseIterable {
    case battle = "battle"
    case salmonRun = "salmonRun"
    
    var localizedName: String {
        switch self {
        case .battle:
            return "对战"
        case .salmonRun:
            return "鲑鱼跑"
        }
    }
}

// MARK: - 日程订阅模型
struct ScheduleSubscription: Codable, Identifiable, Hashable {
    let id: String
    let scheduleType: ScheduleType
    let startTime: Date
    let endTime: Date
    let title: String
    let mode: String?  // 对战模式 (regular, bankara, etc.)
    let rule: String?  // 规则 (turf war, splat zones, etc.)
    let stages: [String]  // 场地名称
    let subscribeTime: Date
    
    // 生成唯一标识符
    static func generateId(type: ScheduleType, startTime: Date, mode: String? = nil, rule: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        let timeString = formatter.string(from: startTime)
        
        if let mode = mode, let rule = rule {
            return "\(type.rawValue)_\(mode)_\(rule)_\(timeString)"
        } else {
            return "\(type.rawValue)_\(timeString)"
        }
    }
    
    // 检查是否已过期
    var isExpired: Bool {
        return endTime < Date()
    }
    
    // 格式化显示标题
    var displayTitle: String {
        if let mode = mode, let rule = rule {
            return "\(title) (\(mode) - \(rule))"
        }
        return title
    }
}

// MARK: - 通知设置
struct NotificationSettings: Codable {
    var isEnabled: Bool = true
    var firstNotificationMinutes: Int = 1440  // 24小时 = 1440分钟
    var secondNotificationMinutes: Int = 5    // 5分钟
    var enableSecondNotification: Bool = true
    
    static let `default` = NotificationSettings()
    
    // 预设选项
    static let firstNotificationOptions = [
        (15, "15分钟前"),
        (30, "30分钟前"), 
        (60, "1小时前"),
        (120, "2小时前"),
        (360, "6小时前"),
        (720, "12小时前"),
        (1440, "1天前"),
        (2880, "2天前")
    ]
    
    static let secondNotificationOptions = [
        (1, "1分钟前"),
        (3, "3分钟前"),
        (5, "5分钟前"),
        (10, "10分钟前"),
        (15, "15分钟前"),
        (30, "30分钟前")
    ]
}
