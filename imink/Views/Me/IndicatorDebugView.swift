//
//  IndicatorDebugView.swift
//  imink
//
//  Created by didi on 2025/12/15.
//

import SwiftUI

struct IndicatorDebugView: View {
    @State private var currentGroupId: String? = nil
    @State private var taskCount = 0
    
    var body: some View {
        List {
            Section(header: Text("任务组测试")) {
                Button("测试：单个任务组（多个子任务）") {
                    testMultipleSubTasks()
                }
                
                Button("测试：延迟 Dismiss 机制") {
                    testDelayedDismiss()
                }
                
                Button("测试：任务组取消") {
                    testTaskGroupCancellation()
                }
            }
            
            Section(header: Text("实时任务测试")) {
                Button("测试：实时任务（后台执行）") {
                    testRealtimeTask()
                }
                
                Button("测试：实时任务 + Live Activity") {
                    testRealtimeTaskWithLiveActivity()
                }
            }
            
            Section(header: Text("Live Activity 测试")) {
                if #available(iOS 16.1, *) {
                    Button("测试：启动 Live Activity") {
                        testStartLiveActivity()
                    }
                    
                    Button("测试：更新 Live Activity") {
                        testUpdateLiveActivity()
                    }
                    
                    Button("测试：结束 Live Activity") {
                        testEndLiveActivity()
                    }
                } else {
                    Text("Live Activity 需要 iOS 16.1+")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("应用生命周期测试")) {
                Button("测试：模拟进入后台") {
                    testAppWillResignActive()
                }
                
                Button("测试：模拟返回前台") {
                    testAppDidBecomeActive()
                }
            }
            
            Section(header: Text("状态信息")) {
                HStack {
                    Text("当前任务组ID")
                    Spacer()
                    if let groupId = currentGroupId {
                        Text(String(groupId.prefix(20)) + "...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("无")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("任务组数量")
                    Spacer()
                    Text("\(Indicators.shared.taskGroupCount)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("清理")) {
                Button("清理所有任务组", role: .destructive) {
                    clearAllTaskGroups()
                }
            }
        }
        .navigationTitle("Indicator Debug")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 测试方法
    
    /// 测试多个子任务
    private func testMultipleSubTasks() {
        // 使用全局任务组ID，所有任务共享同一个indicator
        let groupId = Indicators.globalTaskGroupId
        currentGroupId = groupId
        
        Task { @MainActor in
            _ = Indicators.shared.acquireSharedIndicator(
                groupId: groupId,
                title: "测试多个子任务",
                icon: .progressIndicator
            )
            
            // 任务1
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "任务1")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "任务1")
            
            // 任务2
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "任务2")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "任务2")
            
            // 任务3
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "任务3")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "任务3")
            
            // 完成任务组
            Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: "所有任务完成")
        }
    }
    
    /// 测试延迟 Dismiss 机制
    private func testDelayedDismiss() {
        // 使用全局任务组ID，所有任务共享同一个indicator
        let groupId = Indicators.globalTaskGroupId
        currentGroupId = groupId
        
        Task { @MainActor in
            _ = Indicators.shared.acquireSharedIndicator(
                groupId: groupId,
                title: "测试延迟 Dismiss",
                icon: .progressIndicator
            )
            
            // 任务1完成
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "任务A")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "任务A")
            
            // 延迟0.8秒后添加新任务（测试延迟dismiss是否被取消）
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8秒
            
            // 任务2（应该在延迟期间加入，取消dismiss）
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "任务B")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "任务B")
            
            // 完成任务组
            Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: "延迟测试完成")
        }
    }
    
    /// 测试任务组取消
    private func testTaskGroupCancellation() {
        // 使用全局任务组ID，所有任务共享同一个indicator
        let groupId = Indicators.globalTaskGroupId
        currentGroupId = groupId
        
        Task { @MainActor in
            _ = Indicators.shared.acquireSharedIndicator(
                groupId: groupId,
                title: "测试任务取消",
                icon: .progressIndicator
            )
            
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "任务1")
            
            // 模拟任务被取消
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            
            Indicators.shared.completeTaskGroup(groupId: groupId, success: false, message: "任务已取消")
        }
    }
    
    /// 测试实时任务（后台执行）
    private func testRealtimeTask() {
        // 使用全局任务组ID，所有任务共享同一个indicator
        let groupId = Indicators.globalTaskGroupId
        currentGroupId = groupId
        
        Task { @MainActor in
            _ = Indicators.shared.startRealtimeTask(
                groupId: groupId,
                title: "测试实时任务",
                icon: .progressIndicator
            )
            
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "后台任务1")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "后台任务1")
            
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "后台任务2")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "后台任务2")
            
            Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: "实时任务完成")
        }
    }
    
    /// 测试实时任务 + Live Activity
    @available(iOS 16.1, *)
    private func testRealtimeTaskWithLiveActivity() {
        // 使用全局任务组ID，所有任务共享同一个indicator
        let groupId = Indicators.globalTaskGroupId
        currentGroupId = groupId
        
        Task { @MainActor in
            _ = Indicators.shared.startRealtimeTask(
                groupId: groupId,
                title: "测试实时任务 + Live Activity",
                icon: .progressIndicator
            )
            
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "Live Activity 任务1")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "Live Activity 任务1")
            
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "Live Activity 任务2")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "Live Activity 任务2")
            
            Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: "Live Activity 测试完成")
        }
    }
    
    /// 测试启动 Live Activity
    @available(iOS 16.1, *)
    private func testStartLiveActivity() {
        // 使用全局任务组ID，所有任务共享同一个indicator
        let groupId = Indicators.globalTaskGroupId
        currentGroupId = groupId
        
        Task { @MainActor in
            _ = Indicators.shared.acquireSharedIndicator(
                groupId: groupId,
                title: "测试启动 Live Activity",
                icon: .progressIndicator,
                supportsLiveActivity: true,
                allowBackgroundExecution: true
            )
            
            // Live Activity 会在应用进入后台时自动启动
            // 这里手动触发一下应用生命周期事件来测试
            Indicators.shared.handleAppWillResignActive()
        }
    }
    
    /// 测试更新 Live Activity
    @available(iOS 16.1, *)
    private func testUpdateLiveActivity() {
        guard let groupId = currentGroupId else {
            // 如果没有当前任务组，创建一个
            let newGroupId = "test-la-update-\(UUID().uuidString)"
            currentGroupId = newGroupId
            
            Task { @MainActor in
                _ = Indicators.shared.acquireSharedIndicator(
                    groupId: newGroupId,
                    title: "测试更新 Live Activity",
                    icon: .progressIndicator,
                    supportsLiveActivity: true,
                    allowBackgroundExecution: true
                )
                
                Indicators.shared.handleAppWillResignActive()
                
                Indicators.shared.registerSubTask(groupId: newGroupId, taskName: "更新测试任务")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                Indicators.shared.completeSubTask(groupId: newGroupId, taskName: "更新测试任务")
            }
            return
        }
        
        Task { @MainActor in
            Indicators.shared.registerSubTask(groupId: groupId, taskName: "更新测试任务")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            Indicators.shared.completeSubTask(groupId: groupId, taskName: "更新测试任务")
        }
    }
    
    /// 测试结束 Live Activity
    @available(iOS 16.1, *)
    private func testEndLiveActivity() {
        guard let groupId = currentGroupId else {
            return
        }
        
        Task { @MainActor in
            Indicators.shared.handleAppDidBecomeActive()
        }
    }
    
    /// 测试应用进入后台
    private func testAppWillResignActive() {
        Task { @MainActor in
            Indicators.shared.handleAppWillResignActive()
        }
    }
    
    /// 测试应用返回前台
    private func testAppDidBecomeActive() {
        Task { @MainActor in
            Indicators.shared.handleAppDidBecomeActive()
        }
    }
    
    /// 清理所有任务组
    private func clearAllTaskGroups() {
        Task { @MainActor in
            // 结束所有任务组
            for groupId in Indicators.shared.taskGroups.keys {
                Indicators.shared.completeTaskGroup(groupId: groupId, success: false, message: "已清理")
            }
            currentGroupId = nil
        }
    }
}

#Preview {
    NavigationStack {
        IndicatorDebugView()
    }
}

