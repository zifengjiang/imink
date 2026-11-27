import SwiftUI
import UIKit

/// 自绘可展开底部栏（`ExpandingDock`）动画策略：严格尊重系统「减弱动态效果」设置。
enum DockMotion {
    static let expandResponse: Double = 0.36
    static let expandDamping: Double = 0.78
    static let tabSlideResponse: Double = 0.34
    static let tabSlideDamping: Double = 0.80
    static let scrollHideResponse: Double = 0.38
    static let scrollHideDamping: Double = 0.82
    static let reducedDuration: Double = 0.20

    static func isReduceMotionActive(_ environmentReduceMotion: Bool) -> Bool {
        UIAccessibility.isReduceMotionEnabled || environmentReduceMotion
    }

    static func panelAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: expandResponse, dampingFraction: expandDamping, blendDuration: 0.08)
    }

    static func tabAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: tabSlideResponse, dampingFraction: tabSlideDamping)
    }

    static func scrollHideAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: scrollHideResponse, dampingFraction: scrollHideDamping)
    }
}

/// 四个一级根 Tab 定义（图标取项目 PDF 矢量资源，标题走本地化 + 全站游戏字体）。
enum DockTab: Int, CaseIterable, Identifiable {
    case home = 0
    case battle = 1
    case coop = 2
    case me = 3

    var id: Int { rawValue }

    var iconName: String {
        switch self {
        case .home: return "TabBarHome"
        case .battle: return "TabBarBattle"
        case .coop: return "TabBarSalmonRun"
        case .me: return "TabBarMe"
        }
    }

    var titleKey: String {
        switch self {
        case .home: return "tab_home"
        case .battle: return "tab_battle"
        case .coop: return "tab_salmon_run"
        case .me: return "tab_me"
        }
    }

    var localizedTitle: String {
        titleKey.localized
    }

    var themeColor: Color {
        switch self {
        case .home: return .accentColor
        case .battle: return .spOrange
        case .coop: return .spGreen
        case .me: return .spPurple
        }
    }
}

/// 可展开底部栏：左侧为 4-Tab 轻薄毛玻璃胶囊（展开时向上生长为当前 Tab 模式快筛卡片），右侧为等高独立圆形按钮。
struct ExpandingDock: View {
    @Binding var tabSelection: Int

    @ObservedObject private var dockStore = DockVisibilityStore.shared
    @EnvironmentObject private var battleViewModel: BattleListViewModel
    @EnvironmentObject private var coopViewModel: CoopListViewModel

    @AppStorage("home_page_selectedScheduleType") private var homeScheduleType: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Namespace private var tabSelectionNamespace

    private var reduceMotion: Bool {
        DockMotion.isReduceMotionActive(envReduceMotion)
    }

    private var isExpanded: Bool {
        dockStore.state == .expanded
    }

    private var isScrollingHidden: Bool {
        dockStore.state == .scrollingHidden
    }

    private var activeTab: DockTab {
        DockTab(rawValue: tabSelection) ?? .home
    }

    private var onAccent: Color {
        FilterSheetLayout.onAccent(for: colorScheme)
    }

    /// 当前激活 Tab 是否有生效中的筛选条件（用于右端圆钮角标指示）。
    private var currentTabHasActiveFilter: Bool {
        switch activeTab {
        case .battle:
            return battleViewModel.hasAnyActiveFilter
        case .coop:
            return coopViewModel.hasAnyActiveFilter
        case .home, .me:
            return false
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let screenSize = proxy.size
            let safeBottom = FloatingBarInsets.safeArea.bottom
            let bottomMargin = DockConfig.bottomMargin(safeAreaBottom: safeBottom)
            let hiddenOffset = DockConfig.collapsedHeight + bottomMargin + 16
            let maxPanelHeight = min(screenSize.height * 0.62, 432)

            ZStack(alignment: .bottom) {
                if isExpanded {
                    backdropLayer
                }

                HStack(alignment: .bottom, spacing: DockConfig.dockSpacing) {
                    expandingCapsuleOrPanel(maxPanelHeight: maxPanelHeight)
                        .frame(maxWidth: .infinity)

                    expandToggleCircleButton
                }
                .frame(maxWidth: DockConfig.maxDockWidth)
                .padding(.horizontal, DockConfig.horizontalMargin)
                .onGeometryChange(for: CGRect.self) { geo in
                    geo.frame(in: .named("expandingDockHostSpace"))
                } action: { rect in
                    if !isExpanded, rect.width > 0, rect.height > 0 {
                        DockVisibilityStore.shared.collapsedHitRect = rect
                    }
                }
                .padding(.bottom, bottomMargin)
                .offset(y: isScrollingHidden ? hiddenOffset : 0)
                .scaleEffect(isScrollingHidden && !reduceMotion ? 0.94 : 1.0, anchor: .bottom)
                .opacity(isScrollingHidden ? 0 : 1)
                .allowsHitTesting(!isScrollingHidden)
                .onGeometryChange(for: CGFloat.self) { geo in
                    geo.size.height
                } action: { _ in
                    // 记录收起态下 Dock 顶沿距屏幕物理底边的高度，供 FloatingBarInsets 全局共享
                    if !isExpanded {
                        let restingTop = bottomMargin + DockConfig.collapsedHeight
                        if abs(FloatingBarInsets.measuredCustomDockTop - restingTop) > 0.5 {
                            FloatingBarInsets.measuredCustomDockTop = restingTop
                        }
                    }
                }
            }
            .frame(width: screenSize.width, height: screenSize.height, alignment: .bottom)
            .coordinateSpace(name: "expandingDockHostSpace")
        }
        .ignoresSafeArea()
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .animation(DockMotion.panelAnimation(reduceMotion: envReduceMotion), value: dockStore.state)
        .onAppear {
            let restingTop = DockConfig.defaultCustomDockTop(safeAreaBottom: FloatingBarInsets.safeArea.bottom)
            FloatingBarInsets.measuredCustomDockTop = restingTop
        }
    }

    // MARK: - 1. 变暗背景遮罩

    private var backdropLayer: some View {
        Color.black
            .opacity(colorScheme == .dark ? 0.54 : 0.36)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.generateIfEnabled(.light)
                withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
                    dockStore.collapse()
                }
            }
            .transition(.opacity)
            .accessibilityHidden(true)
    }

    // MARK: - 2. 左侧主容器（收起态 4-Tab 胶囊 ⇄ 展开态模式筛选卡片）

    private func expandingCapsuleOrPanel(maxPanelHeight: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: DockConfig.cornerRadius, style: .continuous)

        return ZStack(alignment: .bottom) {
            if isExpanded {
                expandedCardBody(maxPanelHeight: maxPanelHeight)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.94, anchor: .bottom).combined(with: .opacity)
                    )
            } else {
                collapsedTabBar
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: DockConfig.collapsedHeight)
        .background {
            glassSurface(in: shape, elevated: isExpanded)
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(glassBorderGradient, lineWidth: 1)
        }
        .shadow(
            color: Color.black.opacity(
                isExpanded
                    ? (colorScheme == .dark ? 0.50 : 0.24)
                    : (colorScheme == .dark ? 0.38 : 0.14)
            ),
            radius: isExpanded ? 24 : 14,
            x: 0,
            y: isExpanded ? 10 : 6
        )
    }

    // MARK: - 3. 收起态 4 个 Tab 横排胶囊（高度 48pt <= 49pt）

    private var collapsedTabBar: some View {
        HStack(spacing: 2) {
            ForEach(DockTab.allCases) { tab in
                tabItemButton(tab)
            }
        }
        .padding(DockConfig.tabPillInset)
        .frame(height: DockConfig.collapsedHeight)
        .accessibilityElement(children: .contain)
    }

    private func tabItemButton(_ tab: DockTab) -> some View {
        let isSelected = tabSelection == tab.rawValue
        let hasDot = (tab == .battle && battleViewModel.hasAnyActiveFilter) ||
            (tab == .coop && coopViewModel.hasAnyActiveFilter)

        return Button {
            guard tabSelection != tab.rawValue else { return }
            withAnimation(DockMotion.tabAnimation(reduceMotion: envReduceMotion)) {
                tabSelection = tab.rawValue
            }
        } label: {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
                        .matchedGeometryEffect(id: "dock.activeTabPill", in: tabSelectionNamespace)
                }

                VStack(spacing: 2) {
                    ZStack(alignment: .topTrailing) {
                        Image(tab.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)

                        if hasDot {
                            Circle()
                                .fill(tab.themeColor)
                                .frame(width: 6, height: 6)
                                .offset(x: 4, y: -2)
                        }
                    }

                    Text(tab.localizedTitle)
                        .font(.appSubCaptionMono)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(isSelected ? Color.accentColor : Color.appLabel.opacity(0.68))
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DockConfig.tabPillHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.localizedTitle)
        .accessibilityValue(hasDot ? "已启用筛选" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("expandingDock.tab.\(tab.rawValue)")
    }

    // MARK: - 4. 右端（展开后右下）独立圆形按钮

    private var expandToggleCircleButton: some View {
        let circle = Circle()
        let showAccentRing = isExpanded || currentTabHasActiveFilter

        return Button {
            Haptics.generateIfEnabled(.light)
            withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
                dockStore.toggleExpanded()
            }
        } label: {
            Image(systemName: isExpanded ? "xmark" : "slider.horizontal.3")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(
                    isExpanded
                        ? onAccent
                        : (currentTabHasActiveFilter ? Color.accentColor : Color.appLabel)
                )
                .rotationEffect(.degrees(isExpanded && !reduceMotion ? 90 : 0))
                .frame(width: DockConfig.circleButtonSize, height: DockConfig.circleButtonSize)
                .background {
                    if isExpanded {
                        circle.fill(Color.accentColor)
                    } else {
                        glassSurface(in: circle, elevated: false)
                    }
                }
                .overlay {
                    circle.strokeBorder(
                        showAccentRing
                            ? Color.accentColor.opacity(isExpanded ? 0.0 : 0.45)
                            : Color.white.opacity(colorScheme == .dark ? 0.20 : 0.65),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topTrailing) {
                    if !isExpanded && currentTabHasActiveFilter {
                        Circle()
                            .fill(activeTab.themeColor)
                            .frame(width: 10, height: 10)
                            .overlay {
                                Circle().strokeBorder(Color.listItemBackground, lineWidth: 1.5)
                            }
                            .offset(x: -1, y: 1)
                            .allowsHitTesting(false)
                    }
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.14),
                    radius: 12,
                    x: 0,
                    y: 5
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "收起模式面板" : "展开模式筛选面板")
        .accessibilityValue(currentTabHasActiveFilter ? "筛选已启用" : "")
        .accessibilityIdentifier("expandingDock.toggleButton")
    }

    // MARK: - 5. 展开态面板内容（按当前 Tab 渲染对应模式快筛 + 更多条件入口）

    private func expandedCardBody(maxPanelHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            panelHeader

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    switch activeTab {
                    case .battle:
                        battleModeRows
                    case .coop:
                        coopRuleRows
                    case .home:
                        homeQuickRows
                    case .me:
                        meQuickRows
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: maxPanelHeight - 96)
            .fixedSize(horizontal: false, vertical: true)

            if let footer = moreFilterFooterRow {
                Divider()
                    .opacity(0.22)
                    .padding(.horizontal, 4)

                footer
            }
        }
        .padding(DockConfig.panelPadding)
    }

    private var panelHeader: some View {
        let config: (badge: String, title: String, trailing: String?, accent: Color) = {
            switch activeTab {
            case .battle:
                let status = battleViewModel.filter.modes.isEmpty
                    ? "全部"
                    : "已选 \(battleViewModel.filter.modes.count)"
                return ("对战", "模式筛选", status, .spOrange)
            case .coop:
                let status: String
                if coopViewModel.isShowingShiftCards {
                    status = "卡片视图"
                } else if coopViewModel.filter.rules.isEmpty {
                    status = "全部"
                } else {
                    status = "已选 \(coopViewModel.filter.rules.count)"
                }
                return ("鲑鱼跑", "规则筛选", status, .spGreen)
            case .home:
                return ("主页", "日程与快筛", homeScheduleType == 0 ? "对战日程" : "打工日程", .accentColor)
            case .me:
                return ("我的", "战绩快捷入口", nil, .spPurple)
            }
        }()

        return HStack(spacing: 8) {
            Text(config.badge)
                .font(.appSubCaptionMono)
                .foregroundStyle(config.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(config.accent.opacity(0.16), in: Capsule())

            Text(config.title)
                .font(.appHeadline)
                .foregroundStyle(.appLabel)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let trailing = config.trailing {
                Text(trailing)
                    .font(.appCaptionMono)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - 5.1 对战模式快筛行（真实 BattleMode 枚举）

    private var battleModeRows: some View {
        ForEach(BattleMode.allCases, id: \.rawValue) { mode in
            let isSelected = mode == .all
                ? battleViewModel.filter.modes.isEmpty
                : battleViewModel.filter.modes.contains(mode.rawValue)

            dockPanelRow(
                id: "expandingDock.battleMode.\(mode.rawValue)",
                title: mode.name,
                isSelected: isSelected,
                iconTint: mode.color,
                trailingChevron: true,
                icon: {
                    if mode == .all {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? onAccent : .spOrange)
                    } else {
                        mode.icon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                },
                action: {
                    Haptics.generateIfEnabled(.selectionChanged)
                    Task {
                        await battleViewModel.selectModeFromDock(mode)
                    }
                }
            )
        }
    }

    // MARK: - 5.2 鲑鱼跑规则快筛行（真实 CoopRule 枚举 + 打工卡片）

    @ViewBuilder
    private var coopRuleRows: some View {
        ForEach(CoopRule.allCases, id: \.rawValue) { rule in
            let isSelected = !coopViewModel.isShowingShiftCards && (
                rule == .ALL
                    ? coopViewModel.filter.rules.isEmpty
                    : coopViewModel.filter.rules.contains(rule.rawValue)
            )
            let ruleColor: Color = {
                switch rule {
                case .ALL, .REGULAR: return .spGreen
                case .BIG_RUN: return .spPurple
                case .TEAM_CONTEST: return .spOrange
                }
            }()

            dockPanelRow(
                id: "expandingDock.coopRule.\(rule.rawValue)",
                title: rule.name,
                isSelected: isSelected,
                iconTint: ruleColor,
                trailingChevron: true,
                icon: {
                    if rule == .ALL {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? onAccent : .spGreen)
                    } else {
                        rule.icon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                },
                action: {
                    Haptics.generateIfEnabled(.selectionChanged)
                    Task {
                        await coopViewModel.selectRuleFromDock(rule)
                    }
                }
            )
        }

        dockPanelRow(
            id: "expandingDock.coopRule.SHIFT_CARDS",
            title: "打工卡片",
            isSelected: coopViewModel.isShowingShiftCards,
            iconTint: .spYellow,
            trailingChevron: true,
            icon: {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(coopViewModel.isShowingShiftCards ? onAccent : .spYellow)
            },
            action: {
                Haptics.generateIfEnabled(.selectionChanged)
                Task {
                    await coopViewModel.selectShiftCardsFromDock()
                }
            }
        )
    }

    // MARK: - 5.3 主页与「我」页快捷面板行

    @ViewBuilder
    private var homeQuickRows: some View {
        dockPanelRow(
            id: "expandingDock.home.battleSchedule",
            title: "对战日程",
            isSelected: homeScheduleType == 0,
            iconTint: .spOrange,
            trailingChevron: true,
            icon: {
                Image(.anarchy)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            },
            action: {
                Haptics.generateIfEnabled(.selectionChanged)
                homeScheduleType = 0
            }
        )

        dockPanelRow(
            id: "expandingDock.home.coopSchedule",
            title: "鲑鱼跑日程",
            isSelected: homeScheduleType == 1,
            iconTint: .spGreen,
            trailingChevron: true,
            icon: {
                Image(.salmonRun)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            },
            action: {
                Haptics.generateIfEnabled(.selectionChanged)
                homeScheduleType = 1
            }
        )

        Divider().opacity(0.18).padding(.horizontal, 4)

        dockNavigationRow(
            id: "expandingDock.home.gotoBattleFilter",
            title: "去对战筛选页设置条件…",
            systemImage: "line.3.horizontal.decrease.circle",
            tint: .spOrange,
            badgeCount: battleViewModel.extraActiveFilterCount
        ) {
            closeAndPerform {
                tabSelection = DockTab.battle.rawValue
                battleViewModel.showFilterSheet = true
            }
        }

        dockNavigationRow(
            id: "expandingDock.home.gotoCoopFilter",
            title: "去打工筛选页设置条件…",
            systemImage: "line.3.horizontal.decrease.circle",
            tint: .spGreen,
            badgeCount: coopViewModel.extraActiveFilterCount
        ) {
            closeAndPerform {
                tabSelection = DockTab.coop.rawValue
                coopViewModel.showFilterSheet = true
            }
        }
    }

    @ViewBuilder
    private var meQuickRows: some View {
        dockNavigationRow(
            id: "expandingDock.me.weapon",
            title: "武器榜",
            systemImage: "scope",
            tint: .spOrange,
            badgeCount: 0
        ) {
            closeAndPerform { dockStore.meDestination = "weapon" }
        }

        dockNavigationRow(
            id: "expandingDock.me.stage",
            title: "场地榜",
            systemImage: "map.fill",
            tint: .spLightGreen,
            badgeCount: 0
        ) {
            closeAndPerform { dockStore.meDestination = "stage" }
        }

        dockNavigationRow(
            id: "expandingDock.me.coop",
            title: "打工记录统计",
            systemImage: "drop.fill",
            tint: .spGreen,
            badgeCount: 0
        ) {
            closeAndPerform { dockStore.meDestination = "coop" }
        }

        dockNavigationRow(
            id: "expandingDock.me.trash",
            title: "记录回收站",
            systemImage: "trash.fill",
            tint: .spPink,
            badgeCount: 0
        ) {
            closeAndPerform { dockStore.meDestination = "trash" }
        }

        dockNavigationRow(
            id: "expandingDock.me.settings",
            title: "账号与偏好设置",
            systemImage: "gearshape.fill",
            tint: .accentColor,
            badgeCount: 0
        ) {
            closeAndPerform { dockStore.meDestination = "settings" }
        }
    }

    // MARK: - 5.4 底部固定「去筛选页设置更多条件…」入口

    private var moreFilterFooterRow: AnyView? {
        switch activeTab {
        case .battle:
            return AnyView(
                dockNavigationRow(
                    id: "expandingDock.battle.moreFilters",
                    title: "去筛选页设置更多条件…",
                    systemImage: "slider.horizontal.3",
                    tint: .spOrange,
                    badgeCount: battleViewModel.extraActiveFilterCount
                ) {
                    closeAndPerform {
                        battleViewModel.showFilterSheet = true
                    }
                }
            )
        case .coop:
            return AnyView(
                dockNavigationRow(
                    id: "expandingDock.coop.moreFilters",
                    title: "去筛选页设置更多条件…",
                    systemImage: "slider.horizontal.3",
                    tint: .spGreen,
                    badgeCount: coopViewModel.extraActiveFilterCount
                ) {
                    closeAndPerform {
                        coopViewModel.showFilterSheet = true
                    }
                }
            )
        case .home, .me:
            return nil
        }
    }

    // MARK: - 6. 行组件与材质辅助

    private func dockPanelRow<Icon: View>(
        id: String,
        title: String,
        isSelected: Bool,
        iconTint: Color,
        trailingChevron: Bool,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                    .frame(width: 28, height: 28)
                    .background(
                        isSelected
                            ? Color.black.opacity(colorScheme == .dark ? 0.18 : 0.22)
                            : iconTint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Text(title)
                    .font(.appBody)
                    .foregroundStyle(isSelected ? onAccent : .appLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(onAccent)
                }

                if trailingChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isSelected ? onAccent.opacity(0.85) : Color.secondary.opacity(0.55))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: DockConfig.panelRowHeight)
            .background(
                isSelected
                    ? Color.accentColor
                    : Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private func dockNavigationRow(
        id: String,
        title: String,
        systemImage: String,
        tint: Color,
        badgeCount: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.appCaption)
                    .foregroundStyle(.appLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.appSubCaptionMono)
                        .foregroundStyle(onAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.65))
            }
            .padding(.horizontal, 10)
            .frame(height: DockConfig.panelRowHeight)
            .background(
                Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private func glassSurface<S: Shape>(in shape: S, elevated: Bool) -> some View {
        if reduceTransparency {
            shape.fill(Color.listItemBackground)
                .allowsHitTesting(false)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(
                        colorScheme == .dark
                            ? Color(red: 0.08, green: 0.09, blue: 0.12).opacity(elevated ? 0.72 : 0.56)
                            : Color.white.opacity(elevated ? 0.76 : 0.52)
                    )
                }
                .allowsHitTesting(false)
        }
    }

    private var glassBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.24 : 0.78),
                Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func closeAndPerform(_ block: @escaping () -> Void) {
        Haptics.generateIfEnabled(.light)
        withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
            dockStore.collapse()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            block()
        }
    }
}

/// 将 `ExpandingDock` 承载于独立的透传 `UIView` 层级之上，彻底避免 iOS 26/27 `UITabBarController` 底层视图拦截底部边缘点击，
/// 同时在收起态下将非 Dock 区域的滚动与点击 100% 透传给下层页面。
struct ExpandingDockHost: UIViewControllerRepresentable {
    @Binding var tabSelection: Int

    func makeUIViewController(context: Context) -> DockPassThroughHostController {
        DockPassThroughHostController(rootView: makeHostedDock())
    }

    func updateUIViewController(_ uiViewController: DockPassThroughHostController, context: Context) {
        uiViewController.update(rootView: makeHostedDock())
    }

    private func makeHostedDock() -> AnyView {
        AnyView(
            ExpandingDock(tabSelection: $tabSelection)
                .environmentObject(BattleListViewModel.shared)
                .environmentObject(CoopListViewModel.shared)
                .appGameTypography()
                .appLineHeight()
        )
    }
}

final class DockPassThroughHostController: UIViewController {
    private let hostingController: UIHostingController<AnyView>

    init(rootView: AnyView) {
        self.hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let passThrough = DockPassThroughView()
        passThrough.backgroundColor = .clear
        passThrough.isOpaque = false
        passThrough.hitTestHandler = { [weak self] point, event in
            guard let self else { return nil }
            let store = DockVisibilityStore.shared
            switch store.state {
            case .scrollingHidden:
                return nil
            case .expanded:
                return self.hostingController.view.hitTest(point, with: event)
            case .collapsed:
                let hitZone: CGRect
                if store.collapsedHitRect.width > 0 {
                    hitZone = store.collapsedHitRect.insetBy(dx: -8, dy: -8)
                } else {
                    hitZone = CGRect(
                        x: 0,
                        y: max(0, self.view.bounds.height - 96),
                        width: self.view.bounds.width,
                        height: 96
                    )
                }
                guard hitZone.contains(point) else { return nil }
                return self.hostingController.view.hitTest(point, with: event)
            }
        }
        self.view = passThrough
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hostingController.safeAreaRegions = []
        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    func update(rootView: AnyView) {
        hostingController.rootView = rootView
    }
}

private final class DockPassThroughView: UIView {
    var hitTestHandler: ((CGPoint, UIEvent?) -> UIView?)?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled else { return nil }
        if let handler = hitTestHandler {
            return handler(point, event)
        }
        return super.hitTest(point, with: event)
    }
}
