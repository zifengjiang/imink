//
//  NotificationManager.swift
//  imink
//
//  Created by Assistant on 2024/12/26.
//

import Foundation
import UserNotifications
import UIKit
import os

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Notification")
    
    // 通知标识符
    private static let dataUpdateIdentifier = "data_update_notification"
    
    // 权限状态
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - 请求通知权限
    func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            isAuthorized = granted
            if granted {
                logger.info("通知权限已获得")
            } else {
                logger.warning("通知权限被拒绝")
            }
        } catch {
            logger.error("请求通知权限失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 检查通知权限状态
    func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // MARK: - 发送数据更新通知
    func sendDataUpdateNotification(newDataCount: Int, totalUnviewedCount: Int) async {
        guard isAuthorized else {
            logger.warning("通知权限未授权，无法发送通知")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "数据更新"
        content.sound = .default
        
        // 生成合适的通知内容
        if totalUnviewedCount == newDataCount {
            // 第一次或全部数据都是新的
            content.body = generateNotificationMessage(count: newDataCount, isNew: true)
        } else {
            // 累积的数据
            content.body = generateNotificationMessage(count: totalUnviewedCount, isNew: false)
        }
        
        // 设置角标
        content.badge = NSNumber(value: totalUnviewedCount)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: Self.dataUpdateIdentifier,
            content: content,
            trigger: nil // 立即发送
        )
        
        do {
            // 先移除之前的通知（实现更新效果）
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.dataUpdateIdentifier])
            
            // 添加新通知
            try await UNUserNotificationCenter.current().add(request)
            logger.info("数据更新通知已发送: 新增\(newDataCount)条，总计\(totalUnviewedCount)条未查看")
        } catch {
            logger.error("发送通知失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 生成通知消息
    private func generateNotificationMessage(count: Int, isNew: Bool) -> String {
        if isNew {
            // 新获取的数据
            switch count {
            case 1:
                return "在后台获取到了1条新记录"
            case 2...10:
                return "在后台获取到了\(count)条新记录"
            default:
                return "在后台获取到了\(count)条新记录，快来查看吧！"
            }
        } else {
            // 累积的未查看数据
            switch count {
            case 1:
                return "您有1条记录尚未查看"
            case 2...10:
                return "您有\(count)条记录尚未查看"
            default:
                return "您有\(count)条记录尚未查看，快来查看吧！"
            }
        }
    }
    
    // MARK: - 清除通知
    func clearDataUpdateNotifications() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.dataUpdateIdentifier])
        UNUserNotificationCenter.current().setBadgeCount(0)
        logger.info("数据更新通知已清除")
    }
    
    // MARK: - 清除所有通知
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0)
        logger.info("所有通知已清除")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    
    // 应用在前台时收到通知的处理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 在前台也显示通知
        completionHandler([.alert, .sound, .badge])
    }
    
    // 用户点击通知的处理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        logger.info("用户点击了通知: \(response.notification.request.identifier)")
        
        if response.notification.request.identifier == Self.dataUpdateIdentifier {
            // 用户查看了数据更新通知，标记为已查看
            Task {
                await BackgroundTaskManager.shared.markDataAsViewed()
                await clearDataUpdateNotifications()
            }
        }
        
        completionHandler()
    }
}
