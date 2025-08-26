import SwiftUI
import SplatDatabase


struct SettingPage: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var coopListViewModel: CoopListViewModel
    @EnvironmentObject var backgroundTaskManager: BackgroundTaskManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var subscriptionManager: ScheduleSubscriptionManager
    @State var showFilePicker = false
    @State private var isActivityPresented = false
    @State var showLogoutAlert = false
    @State var showCopySessionIdAlert = false
    @State private var item: Any = URL(fileURLWithPath: SplatDatabase.shared.dbQueue.path)
    var body: some View {
        NavigationStack{
            List{
                Section(header: Text("账户")){
                    Button(action: {
                        showCopySessionIdAlert = true

                    }) {
                        Text("复制会话令牌")
                    }
                    .alert(isPresented: $showCopySessionIdAlert) {
                        Alert(
                            title: Text("复制会话令牌"),
                            message: Text("复制会话令牌的不当传播会导致隐私泄露, 你确定要复制会话令牌吗?"),
                            primaryButton: .destructive(Text("确认")) {
                                UIPasteboard.general.string = AppUserDefaults.shared.sessionToken
                            },
                            secondaryButton: .cancel()
                        )
                    }

                    Button {
                        showLogoutAlert = true
                    } label: {
                        Text("setting_button_logout")
                    }
                    .alert(isPresented: $showLogoutAlert) {
                        Alert(
                            title: Text("退出登录"),
                            message: Text("你确定要退出登录吗？"),
                            primaryButton: .destructive(Text("确认")) {
                                    // 当用户点击"Logout"按钮时，执行注销操作
                                AppUserDefaults.shared.sessionToken = nil
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }

                Section(header: Text("setting_section_user_data")){
                    Button {
                        showFilePicker = true
                    } label: {
                        Text("setting_button_import_user_data")
                    }
                    .sheet(isPresented: $showFilePicker) {
                        FilePickerView(fileType: .zip) { url in
                            dismiss()
                            coopListViewModel.cancel()
                            DataBackup.import(url: url)
                        }
                    }

                    Button {
                        self.isActivityPresented = true
                    } label: {
                        Text("setting_button_export_user_data")
                    }
                    .background(ActivityView(isPresented: $isActivityPresented, item: $item))

                    Button {
                        Task{
                            await NSOAccountManager.shared.refreshGameServiceTokenManual()
                        }
                    } label: {
                        Text("鲑鱼跑记录总数：\(AppState.shared.salmonRunRecordsCount)")
                    }

                    Button {

                    } label: {
                        Text("战斗记录总数：\(AppState.shared.battleRecordsCount)")
                    }

                    Button{
//                        try! SplatDatabase.shared.dbQueue.write{ db in
//                            try db.execute(literal: "DROP TABLE IF EXISTS vsTeam;")
//                            try db.execute(literal: "DROP TABLE if EXISTS battle;")
//                        }
                        try! SplatDatabase.shared.deleteAllBattles()
                    } label: {
                        Text("删除所有战斗数据")
                    }

                }

                Section(header: Text("后台刷新和通知")){
                    // 后台刷新状态诊断
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
                    
                    // Token刷新时间
                    if AppUserDefaults.shared.gameServiceTokenRefreshTime > 0 {
                        HStack {
                            Text("上次Token刷新")
                            Spacer()
                            Text(Date(timeIntervalSince1970: TimeInterval(AppUserDefaults.shared.gameServiceTokenRefreshTime)).toPlayedTimeString(full: true))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    } else {
                        HStack {
                            Text("上次Token刷新")
                            Spacer()
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
                    
                    HStack {
                        Text("通知权限状态")
                        Spacer()
                        Text(notificationManager.isAuthorized ? "已授权" : "未授权")
                            .foregroundStyle(notificationManager.isAuthorized ? .green : .red)
                    }
                    
                    Button {
                        Task {
                            await notificationManager.requestNotificationPermission()
                        }
                    } label: {
                        Text("请求通知权限")
                    }
                    .disabled(notificationManager.isAuthorized)
                    
                    HStack {
                        Text("未查看的数据数量")
                        Spacer()
                        Text("\(backgroundTaskManager.unviewedDataCount)")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        backgroundTaskManager.markDataAsViewed()
                        notificationManager.clearDataUpdateNotifications()
                    } label: {
                        Text("清除所有通知")
                    }
                    
                    Button {
                        Task {
                            // 手动触发后台刷新测试
                            await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
                            await SN3Client.shared.fetchBattles()
                            await SN3Client.shared.fetchCoops()
                        }
                    } label: {
                        Text("手动刷新数据（测试）")
                    }
                    
                    Button {
                        backgroundTaskManager.scheduleBackgroundRefresh()
                    } label: {
                        Text("调度后台刷新任务")
                    }
                    
                    Button {
                        backgroundTaskManager.checkBackgroundTaskStatus()
                    } label: {
                        Text("检查后台任务状态")
                            .foregroundStyle(.blue)
                    }
                    
                    Button {
                        Task {
                            await NSOAccountManager.shared.refreshGameServiceTokenManual()
                        }
                    } label: {
                        Text("手动刷新游戏Token")
                            .foregroundStyle(.green)
                    }
                    
                    #if DEBUG
                    Button {
                        Task {
                            // 测试完整后台刷新流程
                            await backgroundTaskManager.performManualBackgroundRefresh()
                        }
                    } label: {
                        Text("测试完整后台刷新流程")
                            .foregroundStyle(.blue)
                    }
                    
                    Button {
                        backgroundTaskManager.scheduleTestBackgroundRefresh()
                    } label: {
                        Text("调度30秒后台任务(测试)")
                            .foregroundStyle(.purple)
                    }
                    
                    Button {
                        Task {
                            // 测试Debug通知
                            await notificationManager.sendDebugBackgroundRefreshNotification(
                                battlesCount: Int.random(in: 0...3),
                                coopsCount: Int.random(in: 0...2), 
                                success: Bool.random()
                            )
                        }
                    } label: {
                        Text("测试Debug通知样式")
                            .foregroundStyle(.orange)
                    }
                    #endif
                    
                    // 说明信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⚠️ 后台刷新说明：")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                        
                        Text("• iOS系统严格控制后台任务执行")
                        Text("• 需要在系统设置中启用后台应用刷新")
                        Text("• 系统会根据使用情况决定执行频率")
                        Text("• 充电和Wi-Fi环境下更容易执行")
                        Text("• 实际执行时间可能超过15分钟")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Section(header: Text("日程订阅和提醒")) {
                    Toggle("启用日程提醒", isOn: $subscriptionManager.notificationSettings.isEnabled)
                        .onChange(of: subscriptionManager.notificationSettings.isEnabled) { _, _ in
                            subscriptionManager.saveNotificationSettings()
                        }
                    
                    if subscriptionManager.notificationSettings.isEnabled {
                        // 第一次通知设置
                        Picker("第一次提醒时间", selection: $subscriptionManager.notificationSettings.firstNotificationMinutes) {
                            ForEach(NotificationSettings.firstNotificationOptions, id: \.0) { option in
                                Text(option.1).tag(option.0)
                            }
                        }
                        .onChange(of: subscriptionManager.notificationSettings.firstNotificationMinutes) { _, _ in
                            subscriptionManager.saveNotificationSettings()
                        }
                        
                        Toggle("启用二次提醒", isOn: $subscriptionManager.notificationSettings.enableSecondNotification)
                            .onChange(of: subscriptionManager.notificationSettings.enableSecondNotification) { _, _ in
                                subscriptionManager.saveNotificationSettings()
                            }
                        
                        if subscriptionManager.notificationSettings.enableSecondNotification {
                            Picker("二次提醒时间", selection: $subscriptionManager.notificationSettings.secondNotificationMinutes) {
                                ForEach(NotificationSettings.secondNotificationOptions, id: \.0) { option in
                                    Text(option.1).tag(option.0)
                                }
                            }
                            .onChange(of: subscriptionManager.notificationSettings.secondNotificationMinutes) { _, _ in
                                subscriptionManager.saveNotificationSettings()
                            }
                        }
                    }
                    
                    HStack {
                        Text("当前订阅数量")
                        Spacer()
                        Text("\(subscriptionManager.subscriptions.count)")
                            .foregroundStyle(.secondary)
                    }
                    
                    if !subscriptionManager.subscriptions.isEmpty {
                        Button("清除所有订阅") {
                            for subscription in subscriptionManager.subscriptions {
                                subscriptionManager.unsubscribeFromSchedule(subscription.id)
                            }
                        }
                        .foregroundStyle(.red)
                    }
                    
                    Button("清理过期订阅") {
                        subscriptionManager.removeExpiredSubscriptions()
                    }
                }

                Section(header: Text("偏好设置")){
                    Toggle("启用振动", isOn: Preferences.shared.$enableHaptics)
                }

                Section(header: Text("关于Imink")){
                    Button{

                    } label: {
                        Text("鲑鱼跑记录刷新时间： \(Date(timeIntervalSince1970: TimeInterval(AppUserDefaults.shared.coopsRefreshTime)).toPlayedTimeString(full: true))")
                    }

                    Button{

                    } label: {
                        Text("战斗记录刷新时间： \(Date(timeIntervalSince1970: TimeInterval(AppUserDefaults.shared.battlesRefreshTime)).toPlayedTimeString(full: true))")
                    }

                    Button{
                        Task{
                            dismiss()
                            await fetchHistorySchedules()
                        }
                    } label: {
                        Text("获取历史日程")
                    }

                    Button {
                        getNsoVersion { version in
                            if let version = version{
                                AppUserDefaults.shared.NSOVersion = version
                            }
                        }
                    } label: {
                        HStack{
                            Text("NSO版本")
                            Spacer()
                            Text("\(AppUserDefaults.shared.NSOVersion)").foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .navigationTitle("setting_page_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("setting_page_done")
                            .foregroundStyle(.accent)
                            .frame(height: 40)
                    }
                }
            }
            .onAppear {
                Task {
                    await notificationManager.checkNotificationPermission()
                }
            }
        }
    }

    func exportDatabase(){
        let fileManager = FileManager.default
        let databasePath = URL(fileURLWithPath: SplatDatabase.shared.dbQueue.path)

            // Copy to temporary directory
        guard let tempDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let tempFilePath = tempDirectory.appendingPathComponent("db.sqlite")

        do {
            if fileManager.fileExists(atPath: tempFilePath.path) {
                try fileManager.removeItem(at: tempFilePath)
            }
            try fileManager.copyItem(at: databasePath, to: tempFilePath)

            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    if rootViewController.presentedViewController == nil {
                        let documentPicker = UIDocumentPickerViewController(forExporting: [tempFilePath])
                        rootViewController.present(documentPicker, animated: true, completion: nil)
                    } else {
                        rootViewController.dismiss(animated: true) {
                            let documentPicker = UIDocumentPickerViewController(forExporting: [tempFilePath])
                            rootViewController.present(documentPicker, animated: true, completion: nil)
                        }
                    }
                }
            }
        } catch {
            print("Failed to copy file to temporary directory: \(error)")
        }
    }
}




#Preview {
    SettingPage()
}
