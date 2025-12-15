//
//  BackgroundTaskManager.swift
//  imink
//
//  Created by Assistant on 2024/12/26.
//

import Foundation
import UIKit
import BackgroundTasks
import UserNotifications
import SplatDatabase
import GRDB
import os

@MainActor
final class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BackgroundTask")
    
    // 后台任务标识符
    private static let refreshIdentifier = "com.zjoker.imink.refresh"
    private static let scheduleRefreshIdentifier = "com.zjoker.imink.schedule.refresh"
    
    // 通知计数器 - 记录未查看的数据条数
    @Published var unviewedDataCount: Int = 0
    
    // 后台任务状态信息
    @Published var lastBackgroundRefreshTime: Date?
    @Published var backgroundTaskStatus: String = "未知"
    @Published var pendingBackgroundTasks: Int = 0
    
    private init() {
        checkBackgroundTaskStatus()
    }
    
    // MARK: - 注册后台任务
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshIdentifier,
            using: .main
        ) { task in
            Task {
                await self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
            }
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.scheduleRefreshIdentifier,
            using: .main
        ) { task in
            Task {
                await self.handleScheduleRefresh(task: task as! BGAppRefreshTask)
            }
        }
        logger.info("后台任务已注册")
    }
    
    // MARK: - 调度后台刷新
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15分钟后
        
        do {
            try BGTaskScheduler.shared.submit(request)
            backgroundTaskStatus = "已调度"
            updatePendingTasksCount()
            logger.info("后台刷新任务已调度，将在15分钟后执行")
        } catch {
            backgroundTaskStatus = "调度失败: \(error.localizedDescription)"
            logger.error("调度后台刷新任务失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 调度日程后台刷新
    func scheduleScheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.scheduleRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1小时后
        
        do {
            try BGTaskScheduler.shared.submit(request)
            updatePendingTasksCount()
            logger.info("日程后台刷新任务已调度，将在1小时后执行")
        } catch {
            logger.error("调度日程后台刷新任务失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 状态检查
    func checkBackgroundTaskStatus() {
        Task {
            // 检查后台应用刷新权限
            let refreshStatus = await UIApplication.shared.backgroundRefreshStatus
            switch refreshStatus {
            case .available:
                backgroundTaskStatus = "后台刷新可用"
            case .denied:
                backgroundTaskStatus = "用户已禁用后台刷新"
            case .restricted:
                backgroundTaskStatus = "系统限制后台刷新"
            @unknown default:
                backgroundTaskStatus = "未知状态"
            }
            
            updatePendingTasksCount()
        }
    }
    
    private func updatePendingTasksCount() {
        BGTaskScheduler.shared.getPendingTaskRequests { [weak self] requests in
            Task { @MainActor in
                self?.pendingBackgroundTasks = requests.count
                self?.logger.info("待处理的后台任务数量: \(requests.count)")
            }
        }
    }
    
    // MARK: - 处理后台刷新
    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        logger.info("开始执行后台刷新任务")
        
        // 调度下一次后台刷新
        scheduleBackgroundRefresh()
        
        // 创建操作任务
        let operation = Task {
            await performBackgroundDataRefresh()
        }
        
        // 设置过期处理
        task.expirationHandler = {
            self.logger.info("后台任务即将过期，取消操作")
            operation.cancel()
        }
        
        // 等待操作完成
        await operation.value
        
        // 标记任务完成
        task.setTaskCompleted(success: true)
        lastBackgroundRefreshTime = Date()
        updatePendingTasksCount()
        logger.info("后台刷新任务完成")
    }
    
    // MARK: - 处理日程后台刷新
    private func handleScheduleRefresh(task: BGAppRefreshTask) async {
        logger.info("开始执行日程后台刷新任务")
        
        // 调度下一次日程刷新（1小时后）
        scheduleScheduleRefresh()
        
        // 创建操作任务
        let operation = Task {
            await performScheduleRefresh()
        }
        
        // 设置过期处理
        task.expirationHandler = {
            self.logger.info("日程后台任务即将过期，取消操作")
            operation.cancel()
        }
        
        // 等待操作完成
        await operation.value
        
        // 标记任务完成
        task.setTaskCompleted(success: true)
        updatePendingTasksCount()
        logger.info("日程后台刷新任务完成")
    }
    
    // MARK: - 执行后台数据刷新
    private func performBackgroundDataRefresh() async {
        logger.info("开始后台数据刷新")
        
        // 使用全局任务组ID，所有任务共享同一个indicator
        let groupId = Indicators.globalTaskGroupId
        await Indicators.shared.acquireSharedIndicator(
            groupId: groupId,
            title: "正在刷新数据",
            icon: .progressIndicator
        )
        
        var totalNewData = 0
        var success = true
        
        // 刷新token
        await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
        
        // 获取对战记录
        await Indicators.shared.registerSubTask(groupId: groupId, taskName: "数据刷新-获取对战记录")
        let battlesCount = await SN3Client.shared.fetchBattles(groupId: groupId) ?? 0
        await Indicators.shared.completeSubTask(groupId: groupId, taskName: "数据刷新-获取对战记录")
        totalNewData += battlesCount
        
        // 获取鲑鱼跑记录
        await Indicators.shared.registerSubTask(groupId: groupId, taskName: "数据刷新-获取鲑鱼跑记录")
        let coopsCount = await SN3Client.shared.fetchCoops(groupId: groupId) ?? 0
        await Indicators.shared.completeSubTask(groupId: groupId, taskName: "数据刷新-获取鲑鱼跑记录")
        totalNewData += coopsCount
        
        // 完成任务组（只有在没有其他活跃任务时才真正完成）
        let message = totalNewData > 0 ? "成功加载 \(totalNewData) 个新纪录" : "没有新纪录"
        await Indicators.shared.completeTaskGroup(groupId: groupId, success: success, message: message)
        
        // 发送数据更新通知（仅当有新数据时）
        if totalNewData > 0 {
            unviewedDataCount += totalNewData
            await NotificationManager.shared.sendDataUpdateNotification(
                newDataCount: totalNewData,
                totalUnviewedCount: unviewedDataCount
            )
        }
        
    }
    
    // MARK: - 执行日程后台刷新
    private func performScheduleRefresh() async {
        logger.info("开始后台日程刷新")
        
        do {
            // 获取日程数据
            let json = try await Splatoon3InkAPI.schedule.GetJSON()
            
            // 保存到数据库
            try await SplatDatabase.shared.dbQueue.write { db in
                try insertSchedules(json: json, db: db)
            }
            
            // 更新刷新时间
            AppUserDefaults.shared.scheduleRefreshTime = Int(Date().timeIntervalSince1970)
            
            logger.info("日程后台刷新成功")
        } catch {
            logger.error("日程后台刷新失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 获取数据计数的辅助方法
    private func getBattleCount() -> Int {
        do {
            return try SplatDatabase.shared.dbQueue.read { db in
                try Battle.fetchCount(db)
            }
        } catch {
            logger.error("获取对战记录数量失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func getCoopCount() -> Int {
        do {
            return try SplatDatabase.shared.dbQueue.read { db in
                try Coop.fetchCount(db)
            }
        } catch {
            logger.error("获取鲑鱼跑记录数量失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - 重置未查看计数
    func markDataAsViewed() {
        unviewedDataCount = 0
        logger.info("数据已标记为已查看")
    }
    
    // MARK: - 手动触发后台数据刷新（用于测试）
    func performManualBackgroundRefresh() async {
#if DEBUG
        logger.info("手动触发后台数据刷新（测试模式）")
        await performBackgroundDataRefresh()
        lastBackgroundRefreshTime = Date()
#endif
    }
    
    // MARK: - 强制调度短间隔后台任务（仅用于测试）
    func scheduleTestBackgroundRefresh() {
#if DEBUG
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30秒后
        
        do {
            // 先取消现有任务
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
            try BGTaskScheduler.shared.submit(request)
            backgroundTaskStatus = "测试任务已调度(30秒)"
            updatePendingTasksCount()
            logger.info("测试后台刷新任务已调度，将在30秒后执行")
        } catch {
            backgroundTaskStatus = "测试调度失败: \(error.localizedDescription)"
            logger.error("调度测试后台刷新任务失败: \(error.localizedDescription)")
        }
#endif
    }
    
    // MARK: - 强制调度短间隔日程刷新任务（仅用于测试）
    func scheduleTestScheduleRefresh() {
#if DEBUG
        let request = BGAppRefreshTaskRequest(identifier: Self.scheduleRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30秒后
        
        do {
            // 先取消现有任务
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.scheduleRefreshIdentifier)
            try BGTaskScheduler.shared.submit(request)
            updatePendingTasksCount()
            logger.info("测试日程刷新任务已调度，将在30秒后执行")
        } catch {
            logger.error("调度测试日程刷新任务失败: \(error.localizedDescription)")
        }
#endif
    }
    
    // MARK: - 手动触发日程刷新（用于测试）
    func performManualScheduleRefresh() async {
#if DEBUG
        logger.info("手动触发日程刷新（测试模式）")
        await performScheduleRefresh()
#endif
    }
    
    // MARK: - 应用生命周期处理
    func handleAppWillResignActive() {
        scheduleBackgroundRefresh()
        scheduleScheduleRefresh()
        logger.info("应用进入后台，已调度后台刷新和日程刷新")
    }
    
    func handleAppDidBecomeActive() {
        // 取消待处理的后台任务（如果用户返回应用）
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.scheduleRefreshIdentifier)
        logger.info("应用进入前台，已取消待处理的后台任务")
    }
}
