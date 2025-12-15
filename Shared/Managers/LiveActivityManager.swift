//
//  LiveActivityManager.swift
//  imink
//
//  Created by didi on 2025/12/14.
//


//
//  LiveActivityManager.swift
//  imink
//
//  Created by Assistant
//

import Foundation
import ActivityKit
import SwiftUI

// 注意：IndicatorTaskGroup 在 IndicatorsKit 中定义
// 由于是 internal 访问级别，需要在同一模块中

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private init() {}
    
    /// 检查 Live Activity 是否可用（iOS 16+）
    var isAvailable: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }
    
    /// 启动 Live Activity
    /// - Parameter taskGroup: 任务组
    /// - Returns: Activity token（如果成功）
    @available(iOS 16.1, *)
    func startActivity(for taskGroup: IndicatorTaskGroup) -> String? {
        guard isAvailable else { return nil }
        
        // 检查是否已经有活动的 Live Activity
        if let existingToken = taskGroup.liveActivityToken {
            // 更新现有的 Live Activity
            updateActivity(for: taskGroup)
            return existingToken
        }
        
        let attributes = TaskGroupActivityAttributes(
            groupId: taskGroup.id,
            iconName: iconName(for: taskGroup.icon)
        )
        
        let initialState = TaskGroupActivityAttributes.ContentState(
            title: taskGroup.title,
            subtitle: taskGroup.generateSubtitle(),
            progress: taskGroup.progress,
            activeTasks: Array(taskGroup.activeTasks),
            completedTasks: Array(taskGroup.completedTasks),
            status: .inProgress
        )
        
        do {
            let activity = try Activity<TaskGroupActivityAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            
            taskGroup.liveActivityToken = activity.id
            return activity.id
        } catch {
            print("启动 Live Activity 失败: \(error)")
            return nil
        }
    }
    
    /// 更新 Live Activity
    /// - Parameter taskGroup: 任务组
    @available(iOS 16.1, *)
    func updateActivity(for taskGroup: IndicatorTaskGroup) {
        guard isAvailable,
              let token = taskGroup.liveActivityToken else { return }
        
        let contentState = TaskGroupActivityAttributes.ContentState(
            title: taskGroup.title,
            subtitle: taskGroup.generateSubtitle(),
            progress: taskGroup.progress,
            activeTasks: Array(taskGroup.activeTasks),
            completedTasks: Array(taskGroup.completedTasks),
            status: taskGroup.isCompleted() ? .completed : .inProgress
        )
        
        Task { @MainActor in
            for activity in Activity<TaskGroupActivityAttributes>.activities {
                if activity.id == token {
                    await activity.update(using: contentState)
                    break
                }
            }
        }
    }
    
    /// 结束 Live Activity
    /// - Parameter taskGroup: 任务组
    /// - Parameter finalState: 最终状态（可选）
    @available(iOS 16.1, *)
    func endActivity(for taskGroup: IndicatorTaskGroup, finalState: TaskGroupActivityAttributes.ContentState? = nil) {
        guard let token = taskGroup.liveActivityToken else { return }
        
        Task { @MainActor in
            var foundActivity: Activity<TaskGroupActivityAttributes>? = nil
            
            for activity in Activity<TaskGroupActivityAttributes>.activities {
                if activity.id == token {
                    foundActivity = activity
                    break
                }
            }
            
            guard let activity = foundActivity else { return }
            
            if let finalState = finalState {
                await activity.update(using: finalState)
                // 延迟后结束
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            }
            
            await activity.end(dismissalPolicy: .immediate)
            taskGroup.liveActivityToken = nil
        }
    }
    
    /// 从 Live Activity 同步状态到任务组
    /// - Parameter taskGroup: 任务组
    @available(iOS 16.1, *)
    func syncFromActivity(to taskGroup: IndicatorTaskGroup) {
        guard let token = taskGroup.liveActivityToken else { return }
        
        for activity in Activity<TaskGroupActivityAttributes>.activities {
            if activity.id == token {
                let contentState = activity.contentState
                // 同步状态（如果需要）
                // 注意：Live Activity 是只读的，这里主要是读取状态用于显示
                // 实际的任务状态应该由应用内逻辑管理
                // 如果需要，可以在这里更新 taskGroup 的显示状态
                break
            }
        }
    }
    
    /// 将 Indicator.Icon 转换为系统图标名称
    private func iconName(for icon: Indicator.Icon) -> String {
        switch icon {
        case .progressIndicator:
            return "arrow.clockwise"
        case .progressBar:
            return "chart.bar.fill"
        case .success:
            return "checkmark.circle.fill"
        case .image(let image):
            // 对于自定义图片，返回默认图标
            return "arrow.clockwise"
        case .systemImage(let name):
            return name
        }
    }
}

