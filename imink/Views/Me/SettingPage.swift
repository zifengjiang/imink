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
    @State var showFAPIIntervalAlert = false
    @State private var fapiIntervalMinutes: String = ""
    @State private var item: Any = URL(fileURLWithPath: SplatDatabase.shared.dbQueue.path)
    
    // 新增状态变量
    @State private var isUpdatingByname = false
    @State private var bynameUpdateProgress: BynameUpdateProgress?
    
    // 手动输入token相关状态
    @State private var showManualTokenAlert = false
    @State private var manualTokenInput: String = ""
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

                    .alert("设置FAPI请求间隔", isPresented: $showFAPIIntervalAlert) {
                        TextField("请输入间隔分钟数", text: $fapiIntervalMinutes)
                            .keyboardType(.numberPad)
                        Button("确定") {
                            if let minutes = Int(fapiIntervalMinutes), minutes > 0 {
                                AppUserDefaults.shared.fapiRequestInterval = minutes * 60000 // 转换为毫秒
                            }
                        }
                        Button("取消", role: .cancel) { }
                    } message: {
                        Text("当前间隔：\(AppUserDefaults.shared.fapiRequestInterval / 60000)分钟\n请输入新的间隔时间（分钟）：")
                    }

                    // 手动输入游戏服务令牌
                    Toggle("使用手动游戏服务令牌", isOn: Binding(
                        get: { AppUserDefaults.shared.useManualGameServiceToken },
                        set: { AppUserDefaults.shared.useManualGameServiceToken = $0 }
                    ))
                    
                    if AppUserDefaults.shared.useManualGameServiceToken {
                        Button("设置游戏服务令牌") {
                            manualTokenInput = AppUserDefaults.shared.manualGameServiceToken ?? ""
                            showManualTokenAlert = true
                        }
                        .foregroundColor(.blue)
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
                            Text("请输入您的游戏服务令牌。此令牌用于访问Nintendo Switch Online服务。")
                        }

                        if let token = AppUserDefaults.shared.manualGameServiceToken, !token.isEmpty {
                            HStack {
                                Text("当前令牌:")
                                    .foregroundColor(.secondary)
                                Text("\(String(token.prefix(20)))...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
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
                        Task { @MainActor in
                            // 使用实时任务功能，支持后台执行
                            let groupId = "manual-refresh-\(UUID().uuidString)"
                            _ = Indicators.shared.startRealtimeTask(
                                groupId: groupId,
                                title: "正在刷新数据",
                                icon: .progressIndicator
                            )
                            
                            // 刷新token
                            await NSOAccountManager.shared.refreshGameServiceTokenIfNeeded()
                            
                            // 获取对战记录
                            await Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取对战记录")
                            _ = await SN3Client.shared.fetchBattles(groupId: groupId)
                            await Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取对战记录")
                            
                            // 获取鲑鱼跑记录
                            await Indicators.shared.registerSubTask(groupId: groupId, taskName: "获取鲑鱼跑记录")
                            _ = await SN3Client.shared.fetchCoops(groupId: groupId)
                            await Indicators.shared.completeSubTask(groupId: groupId, taskName: "获取鲑鱼跑记录")
                            
                            // 完成任务组
                            await Indicators.shared.completeTaskGroup(groupId: groupId, success: true, message: "刷新完成")
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
                            do{
                                try await NSOAccountManager.shared.refreshGameServiceTokenManual()
                            }catch{
                                logError(error)
                            }
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
                
                Section(header: Text("FAPI设置")){
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
                    
                    Button {
                        // 重置FAPI请求时间
                        AppUserDefaults.shared.fapiLastRequestTime = 0
                    } label: {
                        Text("重置FAPI请求时间")
                            .foregroundStyle(.orange)
                    }
                    
                    Button {
                        // 显示FAPI间隔设置对话框
                        showFAPIIntervalAlert = true
                    } label: {
                        Text("设置FAPI请求间隔")
                            .foregroundStyle(.blue)
                    }
                    
                    // 快速设置按钮
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
                    
                    // 说明信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ℹ️ FAPI请求间隔说明：")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        
                        Text("• 控制FAPI请求的频率，避免过于频繁的请求")
                        Text("• 在间隔时间内重复请求会显示请求过于频繁提示")
                        Text("• 建议设置为5-30分钟，根据使用频率调整")
                        Text("• 设置为0或负数将禁用间隔限制")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                
                // 手动游戏服务令牌说明
                if AppUserDefaults.shared.useManualGameServiceToken {
                    Section(header: Text("游戏服务令牌说明")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ℹ️ 游戏服务令牌获取方法：")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                            
                            Text("• 游戏服务令牌是用于访问Nintendo Switch Online服务的凭证")
                            Text("• 可通过抓包或开发者工具从网页版SplatNet 3获取")
                            Text("• 令牌通常以'gtoken='开头，是一串长字符串")
                            Text("• 使用手动令牌时将不会自动刷新，需要手动更新")
                            Text("• 如果令牌过期，请重新获取并更新")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
                // 初始化FAPI间隔设置
                fapiIntervalMinutes = String(AppUserDefaults.shared.fapiRequestInterval / 60000)
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

// MARK: - Byname Update Progress
struct BynameUpdateProgress {
    let processed: Int
    let total: Int
    let progress: Double
    
    init(processed: Int, total: Int) {
        self.processed = processed
        self.total = total
        self.progress = total > 0 ? Double(processed) / Double(total) : 0.0
    }
}

// MARK: - Byname Update Functions
extension SettingPage {
    func updateBynameFormattedBatch() async {
        await MainActor.run {
            isUpdatingByname = true
            bynameUpdateProgress = nil
        }
        
        do {
            // 获取需要更新的记录总数
            let totalCount = try await SplatDatabase.shared.dbQueue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player WHERE bynameFormatted IS NULL") ?? 0
            }
            
            if totalCount == 0 {
                await MainActor.run {
                    isUpdatingByname = false
                }
                return
            }
            
            // 分批处理，每批处理10条记录
            let batchSize = 30
            var processedCount = 0
            
            while processedCount < totalCount {
                let currentBatchSize = min(batchSize, totalCount - processedCount)
                
                try await SplatDatabase.shared.dbQueue.write { db in
                    // 获取当前批次的记录
                    let players = try Row.fetchAll(db, sql: "SELECT id, byname FROM player WHERE bynameFormatted IS NULL LIMIT ?", arguments: [currentBatchSize])
                    
                    for player in players {
                        let playerId: Int64 = player["id"]
                        let byname: String = player["byname"]
                        
                        if let formatted = formatBynameSync(byname) {
                            let adjectiveId = getI18nId(by: formatted.adjective, db: db) ?? 0
                            let subjectId = getI18nId(by: formatted.subject, db: db) ?? 0
                            let maleFlag: UInt16 = formatted.male == nil ? 0 : (formatted.male! ? 1 : 2)
                            let bynameFormatted = PackableNumbers([adjectiveId, subjectId, maleFlag])
                            
                            try db.execute(sql: "UPDATE player SET bynameFormatted = ? WHERE id = ?", 
                                          arguments: [bynameFormatted.databaseValue, playerId])
                        }
                    }
                }
                
                processedCount += currentBatchSize
                
                // 更新进度
                await MainActor.run {
                    bynameUpdateProgress = BynameUpdateProgress(processed: processedCount, total: totalCount)
                }
                
                // 短暂延迟，避免阻塞UI
//                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            await MainActor.run {
                isUpdatingByname = false
                bynameUpdateProgress = nil
            }
            
        } catch {
            print("更新bynameFormatted时出错: \(error)")
            await MainActor.run {
                isUpdatingByname = false
                bynameUpdateProgress = nil
            }
        }
    }
    
    nonisolated func getI18nId(by key: String, db: Database) -> UInt16? {
        do {
            let row = try Row.fetchOne(db, sql: "SELECT id FROM i18n WHERE key = ?", arguments: [key])
            return row?["id"] as UInt16?
        } catch {
            print("获取i18n ID时出错: \(error)")
            return nil
        }
    }
}

#Preview {
    SettingPage()
}
