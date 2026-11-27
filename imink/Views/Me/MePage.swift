import SwiftUI

struct MePage: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var dashboard = MeDashboardViewModel()
    @AppStorage("mainViewTabSelection") private var tabSelection: Int = 3
    @State private var expandedFriendId: String?
    @State private var showLoginSheet = false

    private let twoColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    identitySection
                    recentPerformanceSection
                    modeEntrySection
                    deepArchiveSection
                    accountAndSettingsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .fixSafeareaBackground()
            .navigationTitle("tab_me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingPage()) {
                        Image("setting")
                            .resizable()
                            .scaledToFit()
                            .overlay(Color(.accent))
                            .mask {
                                Image("setting")
                                    .resizable()
                                    .scaledToFit()
                            }
                            .frame(width: 24)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        Haptics.generateIfEnabled(.light)
                    })
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                NavigationStack {
                    LoginView(iconName: "TabBarMe", backgroundColor: Color.listBackground)
                        .navigationTitle("账号登录")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("关闭") {
                                    showLoginSheet = false
                                }
                            }
                        }
                }
            }
            .onChange(of: appState.isLogin) { _, isLogin in
                if isLogin {
                    showLoginSheet = false
                }
            }
            .task(id: "\(appState.isLogin)-\(appState.battleRecordsCount)-\(appState.salmonRunRecordsCount)") {
                await dashboard.reload()
            }
        }
    }

    // MARK: - 1. 身份卡（我是谁：铭牌/等级/称号 + 当前赛季标识）

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "身份卡",
                subtitle: "我是谁：当前铭牌、称号段位与赛季状态",
                accent: .spYellow,
                badge: dashboard.identity?.seasonLabel
            )

            if appState.isLogin, let identity = dashboard.identity {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        avatarView(data: identity.avatarData)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(identity.name)
                                    .font(.appTitle)
                                    .foregroundStyle(.appLabel)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)

                                if let rank = identity.rank {
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text("★")
                                            .font(.appCaption)
                                            .foregroundStyle(.spYellow)
                                        Text("\(rank)")
                                            .font(.appMono)
                                            .foregroundStyle(.appLabel)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.spYellow.opacity(0.14), in: Capsule())
                                }

                                if let udemae = identity.udemae, !udemae.isEmpty {
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text(udemae)
                                            .font(.appMono)
                                            .foregroundStyle(.spOrange)
                                        if let maxUdemae = identity.udemaeMax, maxUdemae != udemae {
                                            Text("最高\(maxUdemae)")
                                                .font(.appSubCaptionMono)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.spOrange.opacity(0.14), in: Capsule())
                                }
                            }

                            Text(identity.code.map { "SW-\($0)" } ?? dashboard.lastSyncText)
                                .font(.appCaptionMono)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }

                    if let remoteNameplate = identity.remoteNameplate {
                        NameplateView(nameplate: remoteNameplate)
                            .frame(maxWidth: .infinity)
                    } else if let localNameplate = identity.localNameplate {
                        NameplateView(localData: localNameplate)
                            .frame(maxWidth: .infinity)
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Label(dashboard.lastSyncText, systemImage: "arrow.triangle.2.circlepath")
                            .font(.appCaptionMono)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        NavigationLink(destination: NameplateEditorView()) {
                            HStack(spacing: 4) {
                                Image(systemName: "paintbrush.pointed.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("铭牌编辑器")
                                    .font(.appCaption)
                            }
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if !dashboard.onlineFriends.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("好友动态 (\(dashboard.onlineFriends.count))")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(dashboard.onlineFriends, id: \.id) { friend in
                                        FriendView(friend: friend, expandedFriendId: $expandedFriendId)
                                    }
                                }
                            }
                            .frame(height: 84)
                        }
                    }
                }
                .padding(14)
                .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                loggedOutCard
            }
        }
    }

    private var loggedOutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("尚未登录 Nintendo 账号")
                        .font(.appHeadline)
                        .foregroundStyle(.appLabel)

                    Text("登录后即可展示你的专属铭牌、段位与近期实战趋势。")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button {
                    showLoginSheet = true
                } label: {
                    Text("立即登录同步")
                        .font(.appMono)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                NavigationLink(destination: NameplateEditorView()) {
                    Text("体验铭牌编辑")
                        .font(.appCaption)
                        .foregroundStyle(.appLabel)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 2. 近期表现（我最近打得怎么样：近30天胜率、KD、常用武器 Top3）

    private var recentPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "近期表现",
                subtitle: "我最近打得怎么样：胜率、击倒效率与主力武器",
                accent: .spLightGreen,
                badge: appState.isLogin && dashboard.recent.matchCount > 0 ? dashboard.recent.windowTitle : nil
            )

            if !appState.isLogin {
                emptyBlockCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "登录后生成近期战力画像",
                    detail: "自动统计近 30 天胜率涨跌、KD 变化与最常使用的 Top 3 武器。"
                )
            } else if dashboard.recent.matchCount == 0 && dashboard.recent.recentCoopMatches == 0 {
                emptyBlockCard(
                    icon: "waveform.path.ecg",
                    title: "暂无近期对战与打工记录",
                    detail: "同步最新战绩后，这里会直观呈现胜率趋势与主力武器。"
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if dashboard.recent.matchCount > 0 {
                        LazyVGrid(columns: twoColumns, spacing: 10) {
                            recentMetricTile(
                                label: "周期胜率",
                                value: dashboard.recent.winRate.map { String(format: "%.1f%%", $0) } ?? "--",
                                deltaText: formatPercentDelta(dashboard.recent.winRateDelta),
                                isPositive: (dashboard.recent.winRateDelta ?? 0) >= 0,
                                detail: "\(dashboard.recent.winCount)胜 \(dashboard.recent.loseCount)负 · 共\(dashboard.recent.matchCount)场",
                                tint: .spLightGreen
                            )

                            recentMetricTile(
                                label: "周期 KD",
                                value: dashboard.recent.kd.map { String(format: "%.2f", $0) } ?? "--",
                                deltaText: formatNumberDelta(dashboard.recent.kdDelta),
                                isPositive: (dashboard.recent.kdDelta ?? 0) >= 0,
                                detail: dashboard.recent.kad.map { String(format: "KA/D %.2f", $0) } ?? "击倒/阵亡比",
                                tint: .spOrange
                            )
                        }
                    }

                    if dashboard.recent.recentCoopMatches > 0 {
                        HStack(spacing: 8) {
                            Image(.salmonRun)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                            Text("近 30 天鲑鱼跑")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(dashboard.recent.recentCoopMatches) 场")
                                .font(.appMono)
                                .foregroundStyle(.appLabel)
                            if let rate = dashboard.recent.recentCoopClearRate {
                                Text(String(format: "通关率 %.1f%%", rate))
                                    .font(.appCaptionMono)
                                    .foregroundStyle(.spGreen)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.listBackground.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    if !dashboard.recent.topWeapons.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(dashboard.recent.weaponSampleLabel)
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                NavigationLink(destination: WeaponRecordView()) {
                                    HStack(spacing: 2) {
                                        Text("全部武器")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.appCaption)
                                    .foregroundStyle(Color.accentColor)
                                }
                            }

                            VStack(spacing: 8) {
                                ForEach(Array(dashboard.recent.topWeapons.enumerated()), id: \.element.id) { idx, weapon in
                                    HStack(spacing: 10) {
                                        Text("#\(idx + 1)")
                                            .font(.appCaptionMono)
                                            .foregroundStyle(idx == 0 ? Color.spOrange : .secondary)
                                            .frame(width: 22, alignment: .leading)

                                        Image(weapon.imageName)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(4)
                                            .frame(width: 34, height: 34)
                                            .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        Text(weapon.nameId.localizedFromSplatNet)
                                            .font(.appBody)
                                            .foregroundStyle(.appLabel)
                                            .lineLimit(1)

                                        Spacer(minLength: 8)

                                        Text("\(weapon.matchCount)场")
                                            .font(.appCaptionMono)
                                            .foregroundStyle(.secondary)

                                        Text(String(format: "%.1f%%", weapon.winRate))
                                            .font(.appMono)
                                            .foregroundStyle(weapon.winRate >= 50 ? Color.spLightGreen : .appLabel)
                                            .frame(width: 52, alignment: .trailing)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.listBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func recentMetricTile(
        label: String,
        value: String,
        deltaText: String?,
        isPositive: Bool,
        detail: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 4) {
                Text(label)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let deltaText {
                    Text(deltaText)
                        .font(.appSubCaptionMono)
                        .foregroundStyle(isPositive ? Color.spLightGreen : Color.spPink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (isPositive ? Color.spLightGreen : Color.spPink).opacity(0.14),
                            in: Capsule()
                        )
                }
            }

            Text(value)
                .font(.system(size: 24, weight: .bold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .font(.appSubCaptionMono)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.listBackground.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - 3. 分模式入口（对战 / 打工 关键指标 + 一键进入）

    private var modeEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "分模式战绩",
                subtitle: "核心模式总览：一眼确认对战与打工累计实力",
                accent: .spOrange
            )

            LazyVGrid(columns: twoColumns, spacing: 12) {
                modeCard(
                    title: "对战模式",
                    icon: Image(.anarchy),
                    tint: .spOrange,
                    primaryLabel: "综合胜率",
                    primaryValue: appState.isLogin
                        ? (dashboard.battleOverview.winRate.map { String(format: "%.1f%%", $0) } ?? "--")
                        : "--",
                    secondaryText: appState.isLogin
                        ? "\(dashboard.battleOverview.totalCount.formatted()) 场 · KD \(dashboard.battleOverview.kd.map { String(format: "%.2f", $0) } ?? "--")"
                        : "未登录",
                    ctaTitle: "进入对战"
                ) {
                    tabSelection = 1
                }

                modeCard(
                    title: "鲑鱼跑",
                    icon: Image(.salmonRun),
                    tint: .spGreen,
                    primaryLabel: "综合通关率",
                    primaryValue: appState.isLogin
                        ? (dashboard.coopOverview.clearRate.map { String(format: "%.1f%%", $0) } ?? "--")
                        : "--",
                    secondaryText: appState.isLogin
                        ? coopSecondarySummary
                        : "未登录",
                    ctaTitle: "进入打工"
                ) {
                    tabSelection = 2
                }
            }
        }
    }

    private var coopSecondarySummary: String {
        let countText = "\(dashboard.coopOverview.totalCount.formatted()) 场"
        if let maxEgg = dashboard.coopOverview.maxGoldenEgg, maxEgg > 0 {
            return "\(countText) · 最高 \(maxEgg) 金蛋"
        }
        return countText
    }

    private func modeCard(
        title: String,
        icon: Image,
        tint: Color,
        primaryLabel: String,
        primaryValue: String,
        secondaryText: String,
        ctaTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .padding(6)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.appBody)
                    .foregroundStyle(.appLabel)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryLabel)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                Text(primaryValue)
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(.appLabel)
                    .lineLimit(1)
            }

            Text(secondaryText)
                .font(.appSubCaptionMono)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button(action: action) {
                HStack(spacing: 4) {
                    Text(ctaTitle)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.appCaption)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .top) {
            Capsule()
                .fill(tint)
                .frame(height: 3)
                .padding(.horizontal, 12)
        }
    }

    // MARK: - 4. 深度数据入口（我的长期趋势/擅长什么：武器榜 / 场地榜 / 历史记录）

    private var deepArchiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "深度数据",
                subtitle: "我擅长什么：按武器、场地与模式查阅长期档案",
                accent: .spPink
            )

            LazyVGrid(columns: twoColumns, spacing: 12) {
                archiveLinkCard(
                    title: "武器榜",
                    subtitle: "熟练度星级与胜场排行",
                    systemIcon: "scope",
                    tint: .spOrange,
                    destination: WeaponRecordView()
                )

                archiveLinkCard(
                    title: "场地榜",
                    subtitle: "全地图五规则胜率分布",
                    systemIcon: "map.fill",
                    tint: .spLightGreen,
                    destination: StageRecordView()
                )

                archiveLinkCard(
                    title: "打工记录",
                    subtitle: "工地最高分与头目击倒",
                    systemIcon: "drop.fill",
                    tint: .spGreen,
                    destination: CoopRecordView()
                )

                archiveLinkCard(
                    title: "祭典记录",
                    subtitle: dashboard.battleOverview.festCount > 0
                        ? "累计 \(dashboard.battleOverview.festCount) 场祭典档案"
                        : "祭典胜率与贡献度汇总",
                    systemIcon: "sparkles",
                    tint: .spPink,
                    destination: FestRecordView()
                )
            }
        }
    }

    private func archiveLinkCard<Destination: View>(
        title: String,
        subtitle: String,
        systemIcon: String,
        tint: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: systemIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 28, height: 28)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                Text(title)
                    .font(.appBody)
                    .foregroundStyle(.appLabel)

                Text(subtitle)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. 账户与设置（去哪改设置：账号、同步、通知、回收站、关于）

    private var accountAndSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                title: "账户与设置",
                subtitle: "账号管理、通知提醒、回收站与版本信息",
                accent: .spPurple
            )

            VStack(spacing: 0) {
                settingsRow(
                    icon: "gearshape.fill",
                    tint: .accentColor,
                    title: "账号、同步、通知与关于",
                    subtitle: dashboard.lastSyncText,
                    trailingBadge: nil,
                    destination: SettingPage()
                )

                Divider()
                    .padding(.leading, 48)

                settingsRow(
                    icon: "person.text.rectangle.fill",
                    tint: .spYellow,
                    title: "自定义铭牌编辑器",
                    subtitle: "调整称号、徽章与导出铭牌图片",
                    trailingBadge: nil,
                    destination: NameplateEditorView()
                )

                Divider()
                    .padding(.leading, 48)

                settingsRow(
                    icon: "trash.fill",
                    tint: .spPink,
                    title: "记录回收站",
                    subtitle: "恢复误删记录或永久清理",
                    trailingBadge: dashboard.trashCount > 0 ? "\(dashboard.trashCount)" : nil,
                    destination: TrashView()
                )

                #if DEBUG
                Divider()
                    .padding(.leading, 48)

                settingsRow(
                    icon: "wrench.and.screwdriver.fill",
                    tint: .spOrange,
                    title: "高级与开发者选项",
                    subtitle: "后台任务诊断与 FAPI 配置",
                    trailingBadge: nil,
                    destination: DeveloperSettingsPage()
                )

                Divider()
                    .padding(.leading, 48)

                settingsRow(
                    icon: "iphone.gen3.landscape",
                    tint: .secondary,
                    title: "设备方向测试",
                    subtitle: "调试横竖屏方向锁定",
                    trailingBadge: nil,
                    destination: OrientationTestView()
                )
                #endif
            }
            .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func settingsRow<Destination: View>(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        trailingBadge: String?,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appBody)
                        .foregroundStyle(.appLabel)
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let trailingBadge {
                    Text(trailingBadge)
                        .font(.appCaptionMono)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.listBackground, in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared Helpers

    private func sectionHeader(
        title: String,
        subtitle: String,
        accent: Color,
        badge: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent)
                    .frame(width: 4, height: 16)

                Text(title)
                    .font(.appHeadline)
                    .foregroundStyle(.appLabel)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.appSubCaptionMono)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.listItemBackground, in: Capsule())
                }
            }

            Text(subtitle)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
        }
    }

    private func emptyBlockCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color.listBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appBody)
                    .foregroundStyle(.appLabel)
                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func avatarView(data: Data?) -> some View {
        if let data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 52, height: 52)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func formatPercentDelta(_ delta: Double?) -> String? {
        guard let delta, abs(delta) >= 0.05 else { return nil }
        return String(format: "%@%.1f%%", delta >= 0 ? "▲+" : "▼", delta)
    }

    private func formatNumberDelta(_ delta: Double?) -> String? {
        guard let delta, abs(delta) >= 0.01 else { return nil }
        return String(format: "%@%.2f", delta >= 0 ? "▲+" : "▼", delta)
    }
}

#Preview {
    MePage()
}
