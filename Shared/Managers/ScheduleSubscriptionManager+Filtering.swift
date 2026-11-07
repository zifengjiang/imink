import Foundation
import SplatDatabase

/// 日程订阅的筛选：把首页日程按已订阅的场地 / 规则过滤出来。
extension ScheduleSubscriptionManager {
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
