import SwiftUI
import UIKit

/// 自绘可展开底部栏（`ExpandingDock`）原生动效参数：对齐 iOS 26 系统交互式弹簧，严格尊重「减弱动态效果」。
enum DockMotion {
    static let expandResponse: Double = 0.34
    static let expandDamping: Double = 0.82
    static let interactiveResponse: Double = 0.26
    static let interactiveDamping: Double = 0.84
    static let scrollHideResponse: Double = 0.36
    static let scrollHideDamping: Double = 0.86
    static let reducedDuration: Double = 0.20

    static func isReduceMotionActive(_ environmentReduceMotion: Bool) -> Bool {
        UIAccessibility.isReduceMotionEnabled || environmentReduceMotion
    }

    static func panelAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: expandResponse, dampingFraction: expandDamping)
    }

    static func interactiveDragAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .linear(duration: 0.05)
            : .interactiveSpring(response: interactiveResponse, dampingFraction: interactiveDamping)
    }

    static func tabAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: expandResponse, dampingFraction: expandDamping)
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

/// 可展开底部栏（Liquid Glass 4-Tab 居中对称版）：
/// - 仅保留「主页 / 对战 / 鲑鱼跑 / 我」**4 个等宽对称按钮**，无第 5 颗右侧圆钮；
/// - 采用 iOS 26 `GlassEffectContainer` + `.glassEffect(.regular.interactive(), in:)` + `.glassEffectID` 实现真毛玻璃透明折射与同一玻璃体连续形变；
/// - **二次点击当前已选中的 Tab** 即向上原地形变弹出该 Tab 的模式筛选面板；再次点击同 Tab、点外部遮罩或下滑面板即可收起；
/// - 展开时底部 4-Tab 胶囊常驻充当面板底座/把手（激活 Tab 图标翻转为下箭头提示可再点收起）；单选模式行（40pt 行高、28pt 图标块、仅选中显示 `✓`）点击后立即生效并带轻微回弹自动收起。
struct ExpandingDock: View {
    @Binding var tabSelection: Int

    @ObservedObject private var dockStore = DockVisibilityStore.shared
    @EnvironmentObject private var battleViewModel: BattleListViewModel
    @EnvironmentObject private var coopViewModel: CoopListViewModel

    @AppStorage("home_page_selectedScheduleType") private var homeScheduleType: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Namespace private var glassNamespace
    @Namespace private var tabSelectionNamespace

    @State private var dragOffsetY: CGFloat = 0

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

    var body: some View {
        GeometryReader { proxy in
            let screenSize = proxy.size
            let safeBottom = FloatingBarInsets.safeArea.bottom
            let bottomMargin = DockConfig.bottomMargin(safeAreaBottom: safeBottom)
            let hiddenOffset = DockConfig.collapsedHeight + bottomMargin + 16
            let maxPanelBodyHeight = max(200, min(screenSize.height * 0.68, 496) - DockConfig.collapsedHeight)

            ZStack(alignment: .bottom) {
                if isExpanded {
                    backdropLayer
                }

                GlassEffectContainer(spacing: 0) {
                    morphingGlassPlatter(maxPanelBodyHeight: maxPanelBodyHeight)
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
                .offset(y: isScrollingHidden ? hiddenOffset : dragOffsetY)
                .scaleEffect(isScrollingHidden && !reduceMotion ? 0.94 : 1.0, anchor: .bottom)
                .opacity(isScrollingHidden ? 0 : 1)
                .allowsHitTesting(!isScrollingHidden)
                .onGeometryChange(for: CGFloat.self) { geo in
                    geo.size.height
                } action: { _ in
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

    // MARK: - 1. 轻透背景点击遮罩（底层页面通过 MainView `.blur(radius:)` 产生真实景深虚化，不使用纯灰实色蒙层）

    private var backdropLayer: some View {
        Color.black
            .opacity(
                (colorScheme == .dark ? 0.22 : 0.08) * Double(max(0, 1 - dockStore.dragDismissProgress))
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.generateIfEnabled(.light)
                withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
                    dragOffsetY = 0
                    dockStore.collapse()
                }
            }
            .transition(.opacity)
            .accessibilityHidden(true)
    }

    // MARK: - 2. 居中对称连续变形毛玻璃胶囊/面板主体（展开时上部生长出透明筛选行，底部 4-Tab 胶囊常驻作为面板底座）

    private func morphingGlassPlatter(maxPanelBodyHeight: CGFloat) -> some View {
        let platterShape = RoundedRectangle(cornerRadius: DockConfig.cornerRadius, style: .continuous)

        return VStack(spacing: 0) {
            if isExpanded {
                expandedMenuSection(maxPanelBodyHeight: maxPanelBodyHeight)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                    )

                Rectangle()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.09))
                    .frame(height: 0.6)
                    .padding(.horizontal, 12)
            }

            // 居中对称 4-Tab 胶囊始终保留在底部，展开态下自然成为面板底座与把手，视觉完全连续
            collapsedTabBarHandle
        }
        .frame(maxWidth: .infinity)
        .modifier(
            AdaptiveLiquidGlassModifier(
                shape: platterShape,
                reduceTransparency: reduceTransparency,
                colorScheme: colorScheme
            )
        )
        .glassEffectID("dock.primaryPlatter", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
        .simultaneousGesture(platterVerticalDragGesture)
    }

    // MARK: - 3. 居中对称 4-Tab 胶囊（二次点击当前已选 Tab 弹出/收起面板，高度 48pt <= 49pt）

    private var collapsedTabBarHandle: some View {
        HStack(spacing: 4) {
            ForEach(DockTab.allCases) { tab in
                tabItemButton(tab)
            }
        }
        .padding(DockConfig.tabPillInset)
        .frame(height: DockConfig.collapsedHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }

    private func tabItemButton(_ tab: DockTab) -> some View {
        let isSelected = tabSelection == tab.rawValue
        let hasDot = (tab == .battle && battleViewModel.hasAnyActiveFilter) ||
            (tab == .coop && coopViewModel.hasAnyActiveFilter)

        return Button {
            if isSelected {
                // 在当前已激活 Tab 上再点一次 -> 展开或收起该 Tab 的模式筛选面板
                Haptics.generateIfEnabled(.light)
                withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
                    dragOffsetY = 0
                    dockStore.toggleExpanded()
                }
            } else {
                // 点击其他未激活 Tab -> 切换 Tab（若此前处于展开态则顺滑收起，不直接弹新面板）
                withAnimation(DockMotion.tabAnimation(reduceMotion: envReduceMotion)) {
                    dragOffsetY = 0
                    if isExpanded {
                        dockStore.collapse()
                    }
                    tabSelection = tab.rawValue
                }
            }
        } label: {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? (isExpanded ? 0.30 : 0.24) : (isExpanded ? 0.20 : 0.15)))
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.accentColor.opacity(isExpanded ? 0.32 : 0.22), lineWidth: 0.75)
                        }
                        .matchedGeometryEffect(id: "dock.activeTabPill", in: tabSelectionNamespace)
                }

                VStack(spacing: 2) {
                    ZStack(alignment: .topTrailing) {
                        if isSelected && isExpanded {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 18, height: 18)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        } else {
                            Image(tab.iconName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }

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
                .foregroundStyle(isSelected ? Color.accentColor : Color.appLabel.opacity(0.76))
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DockConfig.tabPillHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.localizedTitle)
        .accessibilityValue(hasDot ? "已启用筛选" : "")
        .accessibilityHint(isSelected ? (isExpanded ? "再次点击收起筛选面板" : "再次点击展开筛选面板") : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("expandingDock.tab.\(tab.rawValue)")
    }

    // MARK: - 5. 展开态透明菜单区（40pt 紧凑行高 + 28pt 图标块，7 项一屏完整容纳）

    private func expandedMenuSection(maxPanelBodyHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            panelGrabberAndHeader

            ViewThatFits(in: .vertical) {
                panelRowsStack

                ScrollView(.vertical, showsIndicators: false) {
                    panelRowsStack
                }
                .frame(maxHeight: maxPanelBodyHeight - 84)
            }

            if let footer = moreFilterFooterRow {
                Rectangle()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    .frame(height: 0.6)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)

                footer
            }
        }
        .padding(.horizontal, DockConfig.panelPadding)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private var panelGrabberAndHeader: some View {
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

        return VStack(spacing: 4) {
            Capsule()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.28 : 0.18))
                .frame(width: 34, height: 4)
                .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Text(config.badge)
                    .font(.appSubCaptionMono)
                    .foregroundStyle(config.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(config.accent.opacity(0.16), in: Capsule())

                Text(config.title)
                    .font(.appBody)
                    .foregroundStyle(.appLabel)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let trailing = config.trailing {
                    Text(trailing)
                        .font(.appSubCaptionMono)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .gesture(expandedHeaderDragGesture)
    }

    @ViewBuilder
    private var panelRowsStack: some View {
        VStack(alignment: .leading, spacing: 2) {
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

    // MARK: - 5.1 对战模式快筛行（真实 BattleMode 枚举，选完自动回弹收起，无多余 chevron）

    private var battleModeRows: some View {
        ForEach(BattleMode.allCases, id: \.rawValue) { mode in
            let isSelected = mode == .all
                ? battleViewModel.filter.modes.isEmpty
                : battleViewModel.filter.modes.contains(mode.rawValue)

            dockSelectableRow(
                id: "expandingDock.battleMode.\(mode.rawValue)",
                title: mode.name,
                isSelected: isSelected,
                iconTint: mode.color,
                icon: {
                    if mode == .all {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.accentColor : .spOrange)
                    } else {
                        mode.icon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                    }
                },
                action: {
                    selectModeAndAutoCollapse {
                        await battleViewModel.selectModeFromDock(mode)
                    }
                }
            )
        }
    }

    // MARK: - 5.2 鲑鱼跑规则快筛行（真实 CoopRule 枚举 + 打工卡片，选完自动回弹收起）

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

            dockSelectableRow(
                id: "expandingDock.coopRule.\(rule.rawValue)",
                title: rule.name,
                isSelected: isSelected,
                iconTint: ruleColor,
                icon: {
                    if rule == .ALL {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.accentColor : .spGreen)
                    } else {
                        rule.icon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                    }
                },
                action: {
                    selectModeAndAutoCollapse {
                        await coopViewModel.selectRuleFromDock(rule)
                    }
                }
            )
        }

        dockSelectableRow(
            id: "expandingDock.coopRule.SHIFT_CARDS",
            title: "打工卡片",
            isSelected: coopViewModel.isShowingShiftCards,
            iconTint: .spYellow,
            icon: {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(coopViewModel.isShowingShiftCards ? Color.accentColor : .spYellow)
            },
            action: {
                selectModeAndAutoCollapse {
                    await coopViewModel.selectShiftCardsFromDock()
                }
            }
        )
    }

    // MARK: - 5.3 主页与「我」页快捷面板行

    @ViewBuilder
    private var homeQuickRows: some View {
        dockSelectableRow(
            id: "expandingDock.home.battleSchedule",
            title: "对战日程",
            isSelected: homeScheduleType == 0,
            iconTint: .spOrange,
            icon: {
                Image(.anarchy)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
            },
            action: {
                selectModeAndAutoCollapse {
                    homeScheduleType = 0
                }
            }
        )

        dockSelectableRow(
            id: "expandingDock.home.coopSchedule",
            title: "鲑鱼跑日程",
            isSelected: homeScheduleType == 1,
            iconTint: .spGreen,
            icon: {
                Image(.salmonRun)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
            },
            action: {
                selectModeAndAutoCollapse {
                    homeScheduleType = 1
                }
            }
        )

        Rectangle()
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
            .frame(height: 0.6)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

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

    // MARK: - 6. 透明毛玻璃行组件（不叠实色块，底层折射色彩自然透出；单选行只显示 ✓ 不显示 ›）

    private func dockSelectableRow<Icon: View>(
        id: String,
        title: String,
        isSelected: Bool,
        iconTint: Color,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                    .frame(width: DockConfig.panelIconSize, height: DockConfig.panelIconSize)
                    .background(
                        iconTint.opacity(isSelected ? 0.22 : 0.14),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Text(title)
                    .font(.appBody)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.appLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: DockConfig.panelRowHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.13))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.26), lineWidth: 0.75)
                        }
                }
            }
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: DockConfig.panelIconSize, height: DockConfig.panelIconSize)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.appCaption)
                    .foregroundStyle(.appLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.appSubCaptionMono)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.16), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.65))
            }
            .padding(.horizontal, 8)
            .frame(height: DockConfig.panelRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }

    // MARK: - 7. 交互式手势驱动（`.interactiveSpring` 跟手下拉收起 / 上拉展开）

    private var expandedHeaderDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard isExpanded else { return }
                let dy = value.translation.height
                withAnimation(DockMotion.interactiveDragAnimation(reduceMotion: envReduceMotion)) {
                    dragOffsetY = dy > 0 ? dy * 0.65 : dy * 0.14
                    dockStore.dragDismissProgress = min(1, max(0, dy / 160))
                }
            }
            .onEnded { value in
                guard isExpanded else { return }
                let dy = value.translation.height
                let predictedY = value.predictedEndTranslation.height
                withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
                    dragOffsetY = 0
                    dockStore.dragDismissProgress = 0
                    if dy > 56 || predictedY > 110 {
                        Haptics.generateIfEnabled(.light)
                        dockStore.collapse()
                    }
                }
            }
    }

    private var platterVerticalDragGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onChanged { value in
                let dy = value.translation.height
                let dx = value.translation.width
                guard isExpanded, abs(dy) > abs(dx) * 1.2 else { return }
                withAnimation(DockMotion.interactiveDragAnimation(reduceMotion: envReduceMotion)) {
                    dragOffsetY = dy > 0 ? dy * 0.65 : dy * 0.14
                    dockStore.dragDismissProgress = min(1, max(0, dy / 160))
                }
            }
            .onEnded { value in
                let dy = value.translation.height
                let dx = value.translation.width
                let predictedY = value.predictedEndTranslation.height
                if isExpanded {
                    withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
                        dragOffsetY = 0
                        dockStore.dragDismissProgress = 0
                        if abs(dy) > abs(dx) * 1.2 && (dy > 44 || predictedY > 100) {
                            Haptics.generateIfEnabled(.light)
                            dockStore.collapse()
                        }
                    }
                } else if abs(dy) > abs(dx) * 1.4 && dy < -32 {
                    Haptics.generateIfEnabled(.light)
                    withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
                        dockStore.expand()
                    }
                }
            }
    }

    // MARK: - 8. 单选完自动收起 & 导航跳转辅助

    private func selectModeAndAutoCollapse(_ work: @escaping () async -> Void) {
        Haptics.generateIfEnabled(.selectionChanged)
        Task { @MainActor in
            await work()
            // 短促停留 80ms 让勾选视觉反馈先落定，随后自动沿原生弹簧曲线收起面板
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
                dragOffsetY = 0
                dockStore.collapse()
            }
        }
    }

    private func closeAndPerform(_ block: @escaping () -> Void) {
        Haptics.generateIfEnabled(.light)
        withAnimation(DockMotion.panelAnimation(reduceMotion: envReduceMotion)) {
            dragOffsetY = 0
            dockStore.collapse()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            block()
        }
    }
}

/// 统一材质封装：优先使用 iOS 26 原生 `.glassEffect(.regular.interactive(), in:)`，
/// 系统开启「降低透明度」时优雅降级为 `.ultraThinMaterial` + `1pt` 白色高光描边 + 柔和阴影。
private struct AdaptiveLiquidGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let reduceTransparency: Bool
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.12),
                    radius: 14,
                    x: 0,
                    y: 6
                )
        } else {
            content
                .glassEffect(.regular.interactive(), in: shape)
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
