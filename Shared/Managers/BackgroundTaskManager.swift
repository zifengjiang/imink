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
    
    // MARK: - 执行后台数据刷新
    private func performBackgroundDataRefresh() async {
        logger.info("开始后台数据刷新")
        
        var totalNewData = 0
        // 刷新token
        await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
        // 获取对战记录
        totalNewData += await SN3Client.shared.fetchBattles() ?? 0
        
        // 获取鲑鱼跑记录
        totalNewData += await SN3Client.shared.fetchCoops() ?? 0
        
        // 发送数据更新通知（仅当有新数据时）
        if totalNewData >= 0 {
            unviewedDataCount += totalNewData
            await NotificationManager.shared.sendDataUpdateNotification(
                newDataCount: totalNewData,
                totalUnviewedCount: unviewedDataCount
            )
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
    
    // MARK: - 应用生命周期处理
    func handleAppWillResignActive() {
        scheduleBackgroundRefresh()
        logger.info("应用进入后台，已调度后台刷新")
    }
    
    func handleAppDidBecomeActive() {
        // 取消待处理的后台任务（如果用户返回应用）
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
        logger.info("应用进入前台，已取消待处理的后台任务")
    }
}
