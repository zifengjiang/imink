//
//  ScheduleSubscriptionManager.swift
//  imink
//
//  Created by Assistant on 2024/12/26.
//

import Foundation
import UserNotifications
import SplatDatabase
import os

@MainActor
final class ScheduleSubscriptionManager: ObservableObject {
    static let shared = ScheduleSubscriptionManager()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ScheduleSubscription")
    
    // 订阅状态
    @Published var subscriptions: [ScheduleSubscription] = []
    @Published var notificationSettings = NotificationSettings.default
    
    private init() {
        loadSubscriptions()
        loadNotificationSettings()
    }
    
    // MARK: - 数据加载
    private func loadSubscriptions() {
        subscriptions = AppUserDefaults.shared.scheduleSubscriptions
        removeExpiredSubscriptions()
    }
    
    private func loadNotificationSettings() {
        notificationSettings = AppUserDefaults.shared.notificationSettings
    }
    
    // MARK: - 订阅管理
    
    /// 订阅日程
    func subscribeToSchedule(_ subscription: ScheduleSubscription) async {
        // 检查是否已订阅
        if subscriptions.contains(where: { $0.id == subscription.id }) {
            logger.info("日程已被订阅: \(subscription.id)")
            return
        }
        
        // 添加订阅
        subscriptions.append(subscription)
        saveSubscriptions()
        
        // 调度通知
        await scheduleNotifications(for: subscription)
        
        logger.info("已订阅日程: \(subscription.displayTitle)")
    }
    
    /// 取消订阅日程
    func unsubscribeFromSchedule(_ subscriptionId: String) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) else {
            return
        }
        
        let subscription = subscriptions[index]
        subscriptions.remove(at: index)
        saveSubscriptions()
        
        // 取消相关通知
        cancelNotifications(for: subscriptionId)
        
        logger.info("已取消订阅: \(subscription.displayTitle)")
    }
    
    /// 检查是否已订阅
    func isSubscribed(_ subscriptionId: String) -> Bool {
        return subscriptions.contains(where: { $0.id == subscriptionId })
    }
    
    /// 从Schedule创建订阅
    func createSubscription(from schedule: Schedule) -> ScheduleSubscription {
        let scheduleType: ScheduleType = schedule.mode == .salmonRun ? .salmonRun : .battle
        let id = ScheduleSubscription.generateId(
            type: scheduleType,
            startTime: schedule.startTime,
            mode: scheduleType == .battle ? schedule.mode.localizedDescription : nil,
            rule: scheduleType == .battle ? schedule.rule1.localizedDescription : nil
        )
        
        let title: String
        let mode: String?
        let rule: String?
        let stages: [String]
        
        if scheduleType == .salmonRun {
            title = "鲑鱼跑 - \(schedule.rule1.localizedDescription)"
            mode = nil
            rule = schedule.rule1.localizedDescription
            stages = schedule._stage.map { $0.nameId.localizedFromSplatNet }
        } else {
            title = "对战 - \(schedule.mode.localizedDescription)"
            mode = schedule.mode.localizedDescription
            rule = schedule.rule1.localizedDescription
            stages = schedule._stage.map { $0.nameId.localizedFromSplatNet }
        }
        
        return ScheduleSubscription(
            id: id,
            scheduleType: scheduleType,
            startTime: schedule.startTime,
            endTime: schedule.endTime,
            title: title,
            mode: mode,
            rule: rule,
            stages: stages,
            subscribeTime: Date()
        )
    }
    
    /// 从Schedule和特定rule创建订阅（用于bankara/fest模式的多规则情况）
    func createSubscription(from schedule: Schedule, specificRule: Schedule.Rule, stages: [ImageMap], isOpen: Bool = false) -> ScheduleSubscription {
        let scheduleType: ScheduleType = .battle
        let ruleDescription = specificRule.localizedDescription + (isOpen ? " (开放)" : " (挑战)")
        let id = ScheduleSubscription.generateId(
            type: scheduleType,
            startTime: schedule.startTime,
            mode: schedule.mode.localizedDescription,
            rule: ruleDescription
        )
        
        let title = "对战 - \(schedule.mode.localizedDescription)"
        let mode = schedule.mode.localizedDescription
        let rule = ruleDescription
        let stageNames = stages.map { $0.nameId.localizedFromSplatNet }
        
        return ScheduleSubscription(
            id: id,
            scheduleType: scheduleType,
            startTime: schedule.startTime,
            endTime: schedule.endTime,
            title: title,
            mode: mode,
            rule: rule,
            stages: stageNames,
            subscribeTime: Date()
        )
    }
    
    // MARK: - 通知管理
    
    /// 为订阅调度通知
    private func scheduleNotifications(for subscription: ScheduleSubscription) async {
        guard notificationSettings.isEnabled else { return }
        
        let startTime = subscription.startTime
        let currentTime = Date()
        
        // 第一次通知
        let firstNotificationTime = startTime.addingTimeInterval(-Double(notificationSettings.firstNotificationMinutes * 60))
        if firstNotificationTime > currentTime {
            await scheduleNotification(
                identifier: "\(subscription.id)_first",
                title: "日程提醒",
                body: generateNotificationBody(for: subscription, isSecond: false),
                triggerDate: firstNotificationTime
            )
        }
        
        // 第二次通知
        if notificationSettings.enableSecondNotification {
            let secondNotificationTime = startTime.addingTimeInterval(-Double(notificationSettings.secondNotificationMinutes * 60))
            if secondNotificationTime > currentTime && secondNotificationTime < startTime {
                await scheduleNotification(
                    identifier: "\(subscription.id)_second",
                    title: "日程即将开始",
                    body: generateNotificationBody(for: subscription, isSecond: true),
                    triggerDate: secondNotificationTime
                )
            }
        }
    }
    
    /// 调度单个通知
    private func scheduleNotification(identifier: String, title: String, body: String, triggerDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "SCHEDULE_REMINDER"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("已调度通知: \(identifier) at \(triggerDate)")
        } catch {
            logger.error("调度通知失败: \(error.localizedDescription)")
        }
    }
    
    /// 生成通知内容
    private func generateNotificationBody(for subscription: ScheduleSubscription, isSecond: Bool) -> String {
        let timePrefix = isSecond ? "即将开始" : "提前提醒"
        let stagesText = subscription.stages.joined(separator: " & ")
        
        if subscription.scheduleType == .salmonRun {
            return "\(timePrefix)：\(subscription.rule ?? "鲑鱼跑") - \(stagesText)"
        } else {
            return "\(timePrefix)：\(subscription.mode ?? "对战") \(subscription.rule ?? "") - \(stagesText)"
        }
    }
    
    /// 取消订阅的所有通知
    private func cancelNotifications(for subscriptionId: String) {
        let identifiers = [
            "\(subscriptionId)_first",
            "\(subscriptionId)_second"
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        logger.info("已取消通知: \(identifiers)")
    }
    
    // MARK: - 数据持久化
    
    private func saveSubscriptions() {
        AppUserDefaults.shared.scheduleSubscriptions = subscriptions
    }
    
    func saveNotificationSettings() {
        AppUserDefaults.shared.notificationSettings = notificationSettings
        
        // 重新调度所有通知
        Task {
            await rescheduleAllNotifications()
        }
    }
    
    /// 重新调度所有通知
    private func rescheduleAllNotifications() async {
        // 取消所有现有通知
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // 为所有活跃订阅重新调度通知
        for subscription in subscriptions where !subscription.isExpired {
            await scheduleNotifications(for: subscription)
        }
        
        logger.info("已重新调度所有通知")
    }
    
    // MARK: - 清理过期订阅
    
    /// 移除过期的订阅
    func removeExpiredSubscriptions() {
        let originalCount = subscriptions.count
        subscriptions.removeAll { $0.isExpired }
        
        if subscriptions.count != originalCount {
            saveSubscriptions()
            logger.info("已移除 \(originalCount - self.subscriptions.count) 个过期订阅")
        }
    }
    
    // MARK: - 筛选功能
    
    /// 获取已订阅的日程ID列表
    func getSubscribedScheduleIds() -> Set<String> {
        return Set(subscriptions.map { $0.id })
    }
    
    /// 筛选包含已订阅场地的对战日程（精确到时间+场地+规则粒度）
    func filterSubscribedBattleSchedules(_ scheduleGroups: [Date: [Schedule]]) -> [Date: [Schedule]] {
        var filteredGroups: [Date: [Schedule]] = [:]
        
        for (date, schedules) in scheduleGroups {
            let filteredSchedules = schedules.filter { schedule in
                // 检查这个日程中是否有被订阅的场地和规则
                return schedule._stage.contains { stage in
                    let stageName = stage.nameId.localizedFromSplatNet
                    return subscriptions.contains { subscription in
                        // 检查订阅是否包含这个场地，时间匹配
                        let stageAndTimeMatch = subscription.stages.contains(stageName) &&
                                               subscription.startTime == schedule.startTime
                        
                        if !stageAndTimeMatch {
                            return false
                        }
                        
                        // 检查mode和rule是否匹配订阅中存储的信息
                        if let subscriptionMode = subscription.mode,
                           let subscriptionRule = subscription.rule {
                            // 对于bankara和fest模式，需要特殊处理开放/挑战规则
                            if schedule.mode == .bankara || schedule.mode == .fest {
                                let scheduleModeDesc = schedule.mode.localizedDescription
                                let scheduleRuleDesc = schedule.rule1.localizedDescription
                                
                                // 检查mode是否匹配
                                if subscriptionMode != scheduleModeDesc {
                                    return false
                                }
                                
                                // 检查规则是否匹配（开放或挑战）
                                let openRule = scheduleRuleDesc + " (开放)"
                                let challengeRule = scheduleRuleDesc + " (挑战)"
                                return subscriptionRule == openRule || subscriptionRule == challengeRule
                            } else {
                                // 其他模式直接比较
                                return subscriptionMode == schedule.mode.localizedDescription &&
                                       subscriptionRule == schedule.rule1.localizedDescription
                            }
                        } else {
                            // 如果没有mode和rule信息，只按场地和时间筛选
                            return true
                        }
                    }
                }
            }
            
            if !filteredSchedules.isEmpty {
                filteredGroups[date] = filteredSchedules
            }
        }
        
        return filteredGroups
    }
    
    /// 筛选包含已订阅场地的鲑鱼跑日程（精确到时间+场地+规则粒度）
    func filterSubscribedSalmonRunSchedules(_ schedules: [Schedule]) -> [Schedule] {
        return schedules.filter { schedule in
            // 检查这个日程中是否有被订阅的场地和规则
            return schedule._stage.contains { stage in
                let stageName = stage.nameId.localizedFromSplatNet
                return subscriptions.contains { subscription in
                    // 检查订阅是否包含这个场地，时间匹配
                    let stageAndTimeMatch = subscription.stages.contains(stageName) &&
                                           subscription.startTime == schedule.startTime
                    
                    if !stageAndTimeMatch {
                        return false
                    }
                    
                    // 检查rule是否匹配订阅中存储的信息
                    if let subscriptionRule = subscription.rule {
                        return subscriptionRule == schedule.rule1.localizedDescription
                    } else {
                        // 如果没有rule信息，只按场地和时间筛选
                        return true
                    }
                }
            }
        }
    }
}

// MARK: - 扩展Schedule模型
extension Schedule.Mode {
    var localizedDescription: String {
        switch self {
        case .regular: return "一般比赛"
        case .bankara: return "蛮颓比赛"  
        case .x: return "X比赛"
        case .event: return "活动比赛"
        case .fest: return "祭典比赛"
        case .salmonRun: return "鲑鱼跑"
        }
    }
}

extension Schedule.Rule {
    var localizedDescription: String {
        switch self {
        case .turfWar: return "占地对战"
        case .splatZones: return "真格区域"
        case .towerControl: return "真格塔楼"
        case .rainmaker: return "真格鱼虎"
        case .clamBlitz: return "真格蛤蜊" 
        case .triColor: return "三色夺宝"
        case .bigRun: return "大型跑"
        case .teamContest: return "团队竞赛"
        case .salmonRun: return "鲑鱼跑"

        }
    }
}
