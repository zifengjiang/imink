import SwiftUI
import SplatDatabase
import Foundation
import GRDB


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
    
    // 新增状态变量
    @State var isUpdatingByname = false
    @State var bynameUpdateProgress: BynameUpdateProgress?

    var body: some View {
        NavigationStack{
            List{
                accountSection

                userDataSection

                notificationSection

                subscriptionSection

                preferenceSection

                aboutSection

                advancedSection
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

    private var accountSection: some View {
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
    }

    private var userDataSection: some View {
                    Section(header: Text("setting_section_user_data")){
                        Button {
                            showFilePicker = true
                        } label: {
                            Text("setting_button_import_user_data")
                        }
                        .sheet(isPresented: $showFilePicker) {
                            FilePickerView(fileType: .zip) { url in
                                dismiss()
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
                        
                        } label: {
                            Text("鲑鱼跑记录总数：\(AppState.shared.salmonRunRecordsCount)")
                        }

                        Button {

                        } label: {
                            Text("战斗记录总数：\(AppState.shared.battleRecordsCount)")
                        }

                    }
    }

    private var notificationSection: some View {
                    Section(header: Text("通知")){
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
                    }
    }

    private var subscriptionSection: some View {
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
    }

    private var preferenceSection: some View {
                    Section(header: Text("偏好设置")){
                        Toggle("启用振动", isOn: Preferences.shared.$enableHaptics)
                    
                        Button {
                            Task {
                                await updateBynameFormattedBatch()
                            }
                        } label: {
                            HStack {
                                Text("更新玩家称号格式")
                                Spacer()
                                if isUpdatingByname {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .disabled(isUpdatingByname)
                    
                        if let updateProgress = bynameUpdateProgress {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("更新进度：\(updateProgress.processed)/\(updateProgress.total)")
                                    Spacer()
                                    Text("\(Int(updateProgress.progress * 100))%")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                                ProgressView(value: updateProgress.progress)
                                    .progressViewStyle(LinearProgressViewStyle())
                            }
                        }
                    }
    }

    private var aboutSection: some View {
                    Section(header: Text("关于Imink")){
                        Button{

                        } label: {
                            Text("鲑鱼跑记录刷新时间： \(Date(timeIntervalSince1970: TimeInterval(AppUserDefaults.shared.coopsRefreshTime)).toPlayedTimeString(full: true))")
                        }

                        Button{

                        } label: {
                            Text("战斗记录刷新时间： \(Date(timeIntervalSince1970: TimeInterval(AppUserDefaults.shared.battlesRefreshTime)).toPlayedTimeString(full: true))")
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

    #if DEBUG
    private var advancedSection: some View {
                    Section(header: Text("高级")) {
                        NavigationLink("高级与开发者选项") {
                            DeveloperSettingsPage()
                        }
                    }
    }
    #endif

    func exportDatabase(){
        let fileManager = FileManager.default
        let databasePath = URL(fileURLWithPath: SplatDatabase.shared.dbQueue.path)

            // Copy to temporary directory
        guard let tempDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let tempFilePath = tempDirectory.appendingPathComponent("db.sqlite")

        do {
            // 先执行 checkpoint，将 WAL 文件合并回主数据库文件
            try SplatDatabase.shared.dbQueue.write { db in
                try db.checkpoint()
            }
            
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
