//
//  IndicatorTaskGroup.swift
//  imink
//
//  Created by didi on 2025/12/14.
//


import Foundation
import SwiftUI

/// 任务组：管理一组相关的异步任务，共享同一个 Indicator
@MainActor
class IndicatorTaskGroup {
    let id: String
    var indicatorId: String
    var activeTasks: Set<String>  // 当前活跃的子任务名称
    var completedTasks: Set<String>  // 已完成的子任务名称
    var title: String
    var icon: Indicator.Icon
    var createdAt: Date
    var progress: Double?  // 整体进度 0.0 - 1.0
    var supportsLiveActivity: Bool  // 是否支持 Live Activity
    var allowBackgroundExecution: Bool  // 是否允许后台执行
    var liveActivityToken: String?  // Live Activity 的 token
    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?  // 后台任务标识符
    var pendingDismissTask: Task<Void, Never>?  // 延迟dismiss任务
    
    init(
        id: String,
        indicatorId: String,
        title: String,
        icon: Indicator.Icon = .progressIndicator,
        supportsLiveActivity: Bool = false,
        allowBackgroundExecution: Bool = false
    ) {
        self.id = id
        self.indicatorId = indicatorId
        self.activeTasks = []
        self.completedTasks = []
        self.title = title
        self.icon = icon
        self.createdAt = Date()
        self.progress = nil
        self.supportsLiveActivity = supportsLiveActivity
        self.allowBackgroundExecution = allowBackgroundExecution
        self.liveActivityToken = nil
        self.backgroundTaskIdentifier = nil
    }
    
    /// 生成任务状态的副标题
    func generateSubtitle() -> String? {
        guard !activeTasks.isEmpty || !completedTasks.isEmpty else {
            return nil
        }
        
        var parts: [String] = []
        
        // 添加已完成的任务
        if !completedTasks.isEmpty {
            let completed = completedTasks.joined(separator: "、")
            parts.append("\(completed)（已完成）")
        }
        
        // 添加进行中的任务
        if !activeTasks.isEmpty {
            let active = activeTasks.joined(separator: "、")
            parts.append(active)
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: "，")
    }
    
    /// 检查是否所有任务都已完成
    func isCompleted() -> Bool {
        return activeTasks.isEmpty && !completedTasks.isEmpty
    }
}

