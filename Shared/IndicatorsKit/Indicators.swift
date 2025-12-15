//
//  Indicators.swift
//  IndicatorsKit
//
//  Created by royal on 17/07/2022.
//

import SwiftUI
import UIKit

// MARK: - Indicators


@Observable
public final class Indicators {
	internal static let animation: Animation = .smooth
    public static let shared = Indicators()
	public private(set) var indicators: [Indicator] = []

	internal var timers: [Indicator.ID: Timer] = [:]
	
	// MARK: - Task Group Management
	internal var taskGroups: [String: IndicatorTaskGroup] = [:]
	internal var liveActivityManager: LiveActivityManager = LiveActivityManager.shared
	
	/// 获取当前任务组数量（用于调试）
	public var taskGroupCount: Int {
		taskGroups.count
	}

	public init() { }

	public func display(_ indicator: Indicator) {
		withAnimation(Self.animation) {
			if let alreadyExistingIndex = indicators.firstIndex(where: { $0.id == indicator.id }) {
				indicators[alreadyExistingIndex] = indicator
			} else {
				indicators.append(indicator)
			}
		}
		setupTimerIfNeeded(for: indicator)
	}

	@inlinable @MainActor
	public func dismiss(_ indicator: Indicator) {
		dismiss(with: indicator.id)
	}

//	@MainActor
	public func dismiss(with id: String) {
        DispatchQueue.main.async{
            guard let index = self.indicators.firstIndex(where: { $0.id == id }) else {
                return
            }
            _ = withAnimation(Self.animation) {
                self.indicators.remove(at: index)
            }
        }
		dismissTimer(for: id)
	}

    public func dismiss(with id: String, after delay: TimeInterval){
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.dismiss(with: id)
        }
    }

    public func updateProgress(for id: String, progress: Double) {
        if let index = indicators.firstIndex(where: { $0.id == id }) {
            withAnimation {
                indicators[index].progress = progress
            }
        }
    }

    public func updateSubtitle(for id: String, subtitle: String) {
        if let index = indicators.firstIndex(where: { $0.id == id }) {
            withAnimation {
                indicators[index].subtitle = subtitle
            }
        }
    }

    public func updateTitle(for id: String?, title: String) {
        if let id = id, let index = indicators.firstIndex(where: { $0.id == id }) {
            withAnimation {
                indicators[index].title = title
            }
        }
    }

    public func updateIcon(for id: String, icon: Indicator.Icon) {
        if let index = indicators.firstIndex(where: { $0.id == id }) {
            withAnimation {
                indicators[index].icon = icon
            }
        }
    }

    public func updateSubtitle(for indicator: Indicator, subtitle: String) {
        updateSubtitle(for: indicator.id, subtitle: subtitle)
    }

	public func updateExpandedText(for id: String, expandedText: String) {
        if let index = indicators.firstIndex(where: { $0.id == id }) {
            withAnimation(.bouncy) {
                indicators[index].expandedText = expandedText
            }
        }
    }
}

// MARK: - Indicators+IndicatorTaskGroup

public extension Indicators {
    /// 创建或获取任务组的共享 Indicator
    /// - Parameters:
    ///   - groupId: 任务组ID，如 "data-refresh", "login-flow"
    ///   - title: 任务组标题
    ///   - icon: 图标类型
    ///   - supportsLiveActivity: 是否支持 Live Activity（iOS 16+）
    ///   - allowBackgroundExecution: 是否允许后台执行
    /// - Returns: 共享的 Indicator ID
    @MainActor
    func acquireSharedIndicator(
        groupId: String,
        title: String,
        icon: Indicator.Icon = .progressIndicator,
        supportsLiveActivity: Bool = false,
        allowBackgroundExecution: Bool = false
    ) -> String {
        // 如果任务组已存在，返回现有的 Indicator ID
        if let existingGroup = taskGroups[groupId] {
            return existingGroup.indicatorId
        }
        
        // 创建新的 Indicator
        let indicatorId = UUID().uuidString
        let indicator = Indicator(
            id: indicatorId,
            icon: icon,
            title: title,
            dismissType: .manual,
            isUserDismissible: false
        )
        
        display(indicator)
        
        // 创建任务组
        let taskGroup = IndicatorTaskGroup(
            id: groupId,
            indicatorId: indicatorId,
            title: title,
            icon: icon,
            supportsLiveActivity: supportsLiveActivity,
            allowBackgroundExecution: allowBackgroundExecution
        )
        
        taskGroups[groupId] = taskGroup
        
        return indicatorId
    }
    
    /// 在任务组中注册子任务
    /// - Parameters:
    ///   - groupId: 任务组ID
    ///   - taskName: 子任务名称，如 "获取对战记录", "获取鲑鱼跑记录"
    @MainActor
    func registerSubTask(groupId: String, taskName: String) {
        guard let taskGroup = taskGroups[groupId] else { return }
        
        // 如果有待处理的延迟dismiss任务，取消它（因为新任务来了）
        if let pendingTask = taskGroup.pendingDismissTask {
            pendingTask.cancel()
            taskGroup.pendingDismissTask = nil
        }
        
        taskGroup.activeTasks.insert(taskName)
        updateGroupTitle(groupId: groupId)
        
        // 如果支持 Live Activity，更新 Live Activity
        if taskGroup.supportsLiveActivity {
            updateLiveActivity(for: groupId)
        }
    }
    
    /// 完成子任务
    /// - Parameters:
    ///   - groupId: 任务组ID
    ///   - taskName: 子任务名称
    @MainActor
    func completeSubTask(groupId: String, taskName: String) {
        guard let taskGroup = taskGroups[groupId] else { return }
        
        taskGroup.activeTasks.remove(taskName)
        taskGroup.completedTasks.insert(taskName)
        updateGroupTitle(groupId: groupId)
        
        // 如果支持 Live Activity，更新 Live Activity
        if taskGroup.supportsLiveActivity {
            updateLiveActivity(for: groupId)
        }
        
        // 如果所有任务都完成了，启动延迟dismiss检查
        if taskGroup.activeTasks.isEmpty {
            scheduleDelayedDismissCheck(for: groupId)
        }
    }
    
    /// 调度延迟dismiss检查
    /// - Parameter groupId: 任务组ID
    /// - Note: 延迟1.5秒后检查，如果确实没有活跃任务且任务组已完成，更新为完成状态
    ///   但不自动dismiss，等待 completeTaskGroup 显式调用
    @MainActor
    private func scheduleDelayedDismissCheck(for groupId: String) {
        guard let taskGroup = taskGroups[groupId] else { return }
        
        // 取消之前的延迟dismiss任务（如果有）
        taskGroup.pendingDismissTask?.cancel()
        
        // 创建新的延迟dismiss任务
        taskGroup.pendingDismissTask = Task { @MainActor [weak self] in
            // 等待1.5秒
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
            
            // 检查任务组是否还存在，以及是否确实没有活跃任务
            guard let self = self,
                  let taskGroup = self.taskGroups[groupId] else { return }
            
            // 再次检查：如果确实没有活跃任务且任务组已完成
            if taskGroup.activeTasks.isEmpty && taskGroup.isCompleted() {
                // 更新indicator为完成状态，但不自动dismiss
                // 等待 completeTaskGroup 显式调用来dismiss
                // 这样可以避免在短时间内多个任务完成时频繁创建/销毁indicator
                self.updateTitle(for: taskGroup.indicatorId, title: "\(taskGroup.title)完成")
                self.updateIcon(for: taskGroup.indicatorId, icon: .success)
            }
            
            // 清理延迟dismiss任务引用
            taskGroup.pendingDismissTask = nil
        }
    }
    
    /// 更新任务组 Indicator 的标题（自动聚合所有子任务状态）
    /// - Parameter groupId: 任务组ID
    @MainActor
    func updateGroupTitle(groupId: String) {
        guard let taskGroup = taskGroups[groupId] else { return }
        
        let subtitle = taskGroup.generateSubtitle()
        updateSubtitle(for: taskGroup.indicatorId, subtitle: subtitle ?? "")
        
        // 如果有进度，更新进度
        if let progress = taskGroup.progress {
            updateProgress(for: taskGroup.indicatorId, progress: progress)
        }
    }
    
    /// 更新 Live Activity（内部方法）
    /// - Parameter groupId: 任务组ID
    @MainActor
    private func updateLiveActivity(for groupId: String) {
        guard let taskGroup = taskGroups[groupId],
              taskGroup.supportsLiveActivity else { return }
        
        if #available(iOS 16.1, *) {
            liveActivityManager.updateActivity(for: taskGroup)
        }
    }
    
    /// 更新任务进度
    /// - Parameters:
    ///   - groupId: 任务组ID
    ///   - progress: 进度值 0.0 - 1.0
    @MainActor
    func updateTaskProgress(groupId: String, progress: Double) {
        guard let taskGroup = taskGroups[groupId] else { return }
        
        taskGroup.progress = max(0.0, min(1.0, progress))
        updateProgress(for: taskGroup.indicatorId, progress: taskGroup.progress!)
        
        // 如果支持 Live Activity，更新 Live Activity
        if taskGroup.supportsLiveActivity {
            updateLiveActivity(for: groupId)
        }
    }
    
    /// 完成整个任务组
    /// - Parameters:
    ///   - groupId: 任务组ID
    ///   - success: 是否成功
    ///   - message: 完成消息（可选）
    /// - Note: 只有在所有子任务都完成后才会 dismiss indicator
    @MainActor
    func completeTaskGroup(groupId: String, success: Bool, message: String? = nil) {
        guard let taskGroup = taskGroups[groupId] else { return }
        
        // 安全检查：如果还有活跃任务，先完成它们（可能是调用方遗漏）
        if !taskGroup.activeTasks.isEmpty {
            // 将所有活跃任务标记为已完成
            for taskName in taskGroup.activeTasks {
                taskGroup.activeTasks.remove(taskName)
                taskGroup.completedTasks.insert(taskName)
            }
            updateGroupTitle(groupId: groupId)
        }
        
        // 更新 Indicator 状态
        let finalTitle = message ?? (success ? "\(taskGroup.title)完成" : "\(taskGroup.title)失败")
        updateTitle(for: taskGroup.indicatorId, title: finalTitle)
        
        if success {
            updateIcon(for: taskGroup.indicatorId, icon: .success)
        } else {
            updateIcon(for: taskGroup.indicatorId, icon: .image(Image(systemName: "xmark.circle.fill")))
        }
        
        // 如果支持 Live Activity，结束 Live Activity
        if taskGroup.supportsLiveActivity {
            let finalState = TaskGroupActivityAttributes.ContentState(
                title: finalTitle,
                subtitle: taskGroup.generateSubtitle(),
                progress: taskGroup.progress ?? 1.0,
                activeTasks: [],
                completedTasks: Array(taskGroup.completedTasks),
                status: success ? .completed : .failed
            )
            if #available(iOS 16.1, *) {
                liveActivityManager.endActivity(for: taskGroup, finalState: finalState)
            }
        }
        
        // 延迟关闭 Indicator（确保所有任务都已完成）
        dismiss(with: taskGroup.indicatorId, after: success ? 2 : 3)
        
        // 取消任何待处理的延迟dismiss任务
        taskGroup.pendingDismissTask?.cancel()
        taskGroup.pendingDismissTask = nil
        
        // 清理任务组（延迟清理，避免频繁创建/销毁）
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒后清理
            await MainActor.run {
                self.taskGroups.removeValue(forKey: groupId)
            }
        }
    }
    
    /// 启动实时任务（后台执行 + Live Activity）
    /// - Parameters:
    ///   - groupId: 任务组ID
    ///   - title: 任务标题
    ///   - icon: 图标类型
    /// - Returns: Indicator ID
    @MainActor
    func startRealtimeTask(
        groupId: String,
        title: String,
        icon: Indicator.Icon = .progressIndicator
    ) -> String {
        let indicatorId = acquireSharedIndicator(
            groupId: groupId,
            title: title,
            icon: icon,
            supportsLiveActivity: true,
            allowBackgroundExecution: true
        )
        
        // 申请后台执行时间
        startBackgroundTask(for: groupId)
        
        // 启动 Live Activity（如果可用）
        if let taskGroup = taskGroups[groupId], taskGroup.supportsLiveActivity {
            if #available(iOS 16.1, *) {
                _ = liveActivityManager.startActivity(for: taskGroup)
            }
        }
        
        return indicatorId
    }
    
    /// 停止实时任务
    /// - Parameter groupId: 任务组ID
    @MainActor
    func stopRealtimeTask(groupId: String) {
        endBackgroundTask(for: groupId)
        if let taskGroup = taskGroups[groupId] {
            dismiss(with: taskGroup.indicatorId)
        }
    }
    
    /// 启动后台任务
    /// - Parameter groupId: 任务组ID
    @MainActor
    private func startBackgroundTask(for groupId: String) {
        guard let taskGroup = taskGroups[groupId],
              taskGroup.allowBackgroundExecution else { return }
        
        let identifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 后台时间即将用完
            Task { @MainActor in
                self?.handleBackgroundTaskExpiration(groupId: groupId)
            }
        }
        
        taskGroup.backgroundTaskIdentifier = identifier
    }
    
    /// 结束后台任务
    /// - Parameter groupId: 任务组ID
    @MainActor
    private func endBackgroundTask(for groupId: String) {
        guard let taskGroup = taskGroups[groupId],
              let identifier = taskGroup.backgroundTaskIdentifier else { return }
        
        UIApplication.shared.endBackgroundTask(identifier)
        taskGroup.backgroundTaskIdentifier = nil
    }
    
    /// 处理后台任务过期
    /// - Parameter groupId: 任务组ID
    @MainActor
    private func handleBackgroundTaskExpiration(groupId: String) {
        guard let taskGroup = taskGroups[groupId] else { return }
        
        // 更新 Indicator 提示用户任务仍在进行
        updateTitle(for: taskGroup.indicatorId, title: "\(taskGroup.title)（后台进行中）")
        
        // 结束后台任务标识符
        taskGroup.backgroundTaskIdentifier = nil
        
        // 注意：这里不结束任务，让系统自然处理
        // 如果任务仍在执行，系统可能会在适当时机继续执行
    }
    
    /// 处理应用即将进入后台
    @MainActor
    func handleAppWillResignActive() {
        // 遍历所有支持实时任务的任务组
        for (groupId, taskGroup) in taskGroups {
            if taskGroup.allowBackgroundExecution && taskGroup.backgroundTaskIdentifier == nil {
                // 申请后台执行时间
                startBackgroundTask(for: groupId)
            }
            
            // 如果支持 Live Activity，启动 Live Activity
            if taskGroup.supportsLiveActivity {
                if #available(iOS 16.1, *) {
                    _ = liveActivityManager.startActivity(for: taskGroup)
                }
            }
        }
    }
    
    /// 处理应用进入后台
    @MainActor
    func handleAppDidEnterBackground() {
        // 确保所有需要后台执行的任务都已申请后台时间
        handleAppWillResignActive()
    }
    
    /// 处理应用返回前台
    @MainActor
    func handleAppDidBecomeActive() {
        // 结束后台任务（应用已返回前台）
        for (groupId, taskGroup) in taskGroups {
            if taskGroup.allowBackgroundExecution {
                endBackgroundTask(for: groupId)
            }
            
            // 如果支持 Live Activity，同步状态并关闭
            if taskGroup.supportsLiveActivity {
                if #available(iOS 16.1, *) {
                    liveActivityManager.syncFromActivity(to: taskGroup)
                    liveActivityManager.endActivity(for: taskGroup)
                }
            }
        }
    }
}

// MARK: - Indicators+Internal

internal extension Indicators {
	func setupTimerIfNeeded(for indicator: Indicator) {
		self.timers[indicator.id]?.invalidate()

		if case .after(let time) = indicator.dismissType {
//			let timer = Timer.scheduledTimer(withTimeInterval: time, repeats: false) { _ in
//				Task { @MainActor [weak self] in
//					self?.dismiss(indicator)
//				}
//			}
//			self.timers[indicator.id] = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + time) { [weak self] in
                self?.dismiss(indicator)
            }
		}
	}

	func dismissTimer(for id: Indicator.ID) {
		timers[id]?.invalidate()
		timers[id] = nil
	}
}

// MARK: - Indicators+Preview

#if DEBUG
internal extension Indicators {
	static func preview(indicators: [Indicator] = [.titleSubtitleExpandedIcon], interval: TimeInterval = 2) -> Indicators {
		let model = Indicators()

		Task {
			try? await Task.sleep(for: .seconds(1))
			for indicator in indicators {
				model.display(indicator)
				try? await Task.sleep(for: .seconds(interval))
			}
		}

		return model
	}
}
#endif
