import SwiftUI
import SplatDatabase
import Foundation
import GRDB

#if DEBUG
struct DeveloperSettingsPage: View {
    @EnvironmentObject var backgroundTaskManager: BackgroundTaskManager
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var showManualTokenAlert = false
    @State private var manualTokenInput = ""
    @State private var showFAPIIntervalAlert = false
    @State private var fapiIntervalMinutes = ""
    @State private var showDeleteAllBattlesAlert = false

    var body: some View {
        List {
            manualTokenSection
            backgroundDiagnosticsSection
            fapiSection
            maintenanceSection
        }
        .navigationTitle("高级与开发者选项")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fapiIntervalMinutes = String(AppUserDefaults.shared.fapiRequestInterval / 60000)
        }
    }

    private var manualTokenSection: some View {
        Section(header: Text("手动游戏服务令牌")) {
            Toggle("使用手动游戏服务令牌", isOn: Binding(
                get: { AppUserDefaults.shared.useManualGameServiceToken },
                set: { AppUserDefaults.shared.useManualGameServiceToken = $0 }
            ))

            if AppUserDefaults.shared.useManualGameServiceToken {
                Button("设置游戏服务令牌") {
                    manualTokenInput = AppUserDefaults.shared.manualGameServiceToken ?? ""
                    showManualTokenAlert = true
                }
                .alert("设置游戏服务令牌", isPresented: $showManualTokenAlert) {
                    TextField("请输入游戏服务令牌", text: $manualTokenInput)
                    Button("确定") {
                        if !manualTokenInput.isEmpty {
                            AppUserDefaults.shared.manualGameServiceToken = manualTokenInput
                        }
                    }
                    Button("清除") {
                        AppUserDefaults.shared.manualGameServiceToken = nil
                        manualTokenInput = ""
                    }
                    Button("取消", role: .cancel) { }
                } message: {
                    Text("请输入用于访问 Nintendo Switch Online 服务的游戏服务令牌。")
                }

                if let token = AppUserDefaults.shared.manualGameServiceToken, !token.isEmpty {
                    HStack {
                        Text("当前令牌")
                        Spacer()
                        Text("\(String(token.prefix(20)))...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("此选项面向调试和临时排障。使用手动令牌时不会自动刷新，过期后需要重新设置。")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var backgroundDiagnosticsSection: some View {
        Section(header: Text("后台任务诊断")) {
            HStack {
                Text("后台刷新状态")
                Spacer()
                Text(backgroundTaskManager.backgroundTaskStatus)
                    .foregroundStyle(backgroundTaskManager.backgroundTaskStatus.contains("可用") ? .green : .orange)
                    .font(.caption)
            }

            if let lastRefresh = backgroundTaskManager.lastBackgroundRefreshTime {
                HStack {
                    Text("上次后台刷新")
                    Spacer()
                    Text(lastRefresh.toPlayedTimeString(full: true))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            HStack {
                Text("上次Token刷新")
                Spacer()
                if AppUserDefaults.shared.gameServiceTokenRefreshTime > 0 {
                    Text(Date(timeIntervalSince1970: TimeInterval(AppUserDefaults.shared.gameServiceTokenRefreshTime)).toPlayedTimeString(full: true))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text("从未刷新")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            HStack {
                Text("待处理后台任务")
                Spacer()
                Text("\(backgroundTaskManager.pendingBackgroundTasks)")
                    .foregroundStyle(.secondary)
            }

            Button("手动刷新数据（测试）") {
                Task { @MainActor in
                    let groupId = "manual-refresh-\(UUID().uuidString)"
                    _ = Indicators.shared.startRealtimeTask(
                        groupId: groupId,
                        title: "正在刷新数据",
                        icon: .progressIndicator
                    )

                    await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()

                    await Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取对战记录")
                    _ = await SN3Client.shared.fetchBattles(groupId: groupId)
                    await Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取对战记录")

                    await Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取鲑鱼跑记录")
                    _ = await SN3Client.shared.fetchCoops(groupId: groupId)
                    await Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取鲑鱼跑记录")

                    await Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: "刷新完成")
                }
            }

            Button("调度后台刷新任务") {
                backgroundTaskManager.scheduleBackgroundRefresh()
            }

            Button("检查后台任务状态") {
                backgroundTaskManager.checkBackgroundTaskStatus()
            }

            Button("手动刷新游戏Token") {
                Task {
                    do {
                        try await NSOAccountManager.shared.refreshGameServiceTokenManual()
                    } catch {
                        logError(error)
                    }
                }
            }

            Button("测试完整后台刷新流程") {
                Task {
                    await backgroundTaskManager.performManualBackgroundRefresh()
                }
            }

            Button("调度30秒后台任务（测试）") {
                backgroundTaskManager.scheduleTestBackgroundRefresh()
            }

            Button("测试Debug通知样式") {
                Task {
                    await notificationManager.sendDebugBackgroundRefreshNotification(
                        battlesCount: Int.random(in: 0...3),
                        coopsCount: Int.random(in: 0...2),
                        success: Bool.random()
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("iOS 会严格控制后台任务执行，需要系统设置中启用后台应用刷新。充电和 Wi-Fi 环境下更容易执行。")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var fapiSection: some View {
        Section(header: Text("FAPI 设置")) {
            HStack {
                Text("FAPI请求间隔")
                Spacer()
                if AppUserDefaults.shared.fapiRequestInterval <= 0 {
                    Text("已禁用")
                        .foregroundStyle(.red)
                } else {
                    Text("\(AppUserDefaults.shared.fapiRequestInterval / 60000)分钟")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("上次FAPI请求")
                Spacer()
                if AppUserDefaults.shared.fapiLastRequestTime > 0 {
                    Text(Date(timeIntervalSince1970: TimeInterval(AppUserDefaults.shared.fapiLastRequestTime / 1000)).toPlayedTimeString(full: true))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text("从未请求")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            Button("重置FAPI请求时间") {
                AppUserDefaults.shared.fapiLastRequestTime = 0
            }
            .foregroundStyle(.orange)

            Button("设置FAPI请求间隔") {
                fapiIntervalMinutes = String(AppUserDefaults.shared.fapiRequestInterval / 60000)
                showFAPIIntervalAlert = true
            }
            .alert("设置FAPI请求间隔", isPresented: $showFAPIIntervalAlert) {
                TextField("请输入间隔分钟数", text: $fapiIntervalMinutes)
                    .keyboardType(.numberPad)
                Button("确定") {
                    if let minutes = Int(fapiIntervalMinutes), minutes >= 0 {
                        AppUserDefaults.shared.fapiRequestInterval = minutes * 60000
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("当前间隔：\(AppUserDefaults.shared.fapiRequestInterval / 60000)分钟。设置为 0 可禁用间隔限制。")
            }

            HStack {
                Text("快速设置")
                Spacer()
                Button("5分钟") {
                    AppUserDefaults.shared.fapiRequestInterval = 5 * 60000
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("15分钟") {
                    AppUserDefaults.shared.fapiRequestInterval = 15 * 60000
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("30分钟") {
                    AppUserDefaults.shared.fapiRequestInterval = 30 * 60000
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("禁用") {
                    AppUserDefaults.shared.fapiRequestInterval = 0
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
            }
        }
    }

    private var maintenanceSection: some View {
        Section(header: Text("维护操作")) {
            Button("获取历史日程") {
                Task {
                    await fetchHistorySchedules()
                }
            }

            Button("删除所有战斗数据", role: .destructive) {
                showDeleteAllBattlesAlert = true
            }
            .alert("删除所有战斗数据", isPresented: $showDeleteAllBattlesAlert) {
                Button("删除", role: .destructive) {
                    try? SplatDatabase.shared.deleteAllBattles()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("此操作会删除本地所有战斗记录，仅用于调试或数据重置。")
            }
        }
    }
}
#endif
