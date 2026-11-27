import SwiftUI
import UIKit

/// 自绘可展开底部栏（`ExpandingDock`）原生动效参数：
/// - 非对称开合弹簧：展开 `response: 0.35, dampingFraction: 0.72`（带轻快微弹），收起 `response: 0.28, dampingFraction: 0.94`（干脆落位不穿底）；
/// - 水平微收腰脉冲（`keyframeAnimator`）：展开宽度先压至 `0.80` 再回弹至 `1.0`，收起先压至 `0.82` 再回稳至 `1.0`；
/// - 逐行错峰上浮：展开按底→顶每行 `delay: index * 0.030s`（`opacity 0→1` + `offset y +10→0` + `blur 3→0`），收起反序顶→底快速收拢（总时长 `≤ 0.18s`）；
/// - 开启系统「减弱动态效果」时全面降级为纯淡入淡出（无位移、无缩放收腰、无模糊过渡）。
enum DockMotion {
    static let expandResponse: Double = 0.35
    static let expandDamping: Double = 0.72
    static let collapseResponse: Double = 0.28
    static let collapseDamping: Double = 0.94
    static let interactiveResponse: Double = 0.26
    static let interactiveDamping: Double = 0.84
    static let scrollHideResponse: Double = 0.36
    static let scrollHideDamping: Double = 0.86
    static let reducedDuration: Double = 0.18

    /// 水平微收腰脉冲峰值比例（展开 `0.80`，收起 `0.82`）。
    static let openSqueezeScale: CGFloat = 0.80
    static let closeSqueezeScale: CGFloat = 0.82

    /// 面板逐行错峰参数（展开自底向上 30ms 步进；收起自顶向下反序且总时长 `8 * 0.011 + 0.088 = 0.176s <= 0.18s`）。
    static let rowOpenStaggerStep: Double = 0.030
    static let rowOpenResponse: Double = 0.32
    static let rowOpenDamping: Double = 0.78
    static let rowInitialOffsetY: CGFloat = 10
    static let rowInitialBlur: CGFloat = 3
    static let rowCloseStaggerStep: Double = 0.011
    static let rowCloseItemDuration: Double = 0.088

    static func isReduceMotionActive(_ environmentReduceMotion: Bool) -> Bool {
        UIAccessibility.isReduceMotionEnabled || environmentReduceMotion
    }

    static func openAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: expandResponse, dampingFraction: expandDamping)
    }

    static func closeAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: collapseResponse, dampingFraction: collapseDamping)
    }

    static func transitionAnimation(to state: DockState, reduceMotion: Bool) -> Animation {
        switch state {
        case .expanded:
            return openAnimation(reduceMotion: reduceMotion)
        case .collapsed:
            return closeAnimation(reduceMotion: reduceMotion)
        case .scrollingHidden:
            return scrollHideAnimation(reduceMotion: reduceMotion)
        }
    }

    static func panelAnimation(reduceMotion: Bool) -> Animation {
        openAnimation(reduceMotion: reduceMotion)
    }

    static func interactiveDragAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .linear(duration: 0.05)
            : .interactiveSpring(response: interactiveResponse, dampingFraction: interactiveDamping)
    }

    static func tabAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: 0.32, dampingFraction: 0.84)
    }

    static func scrollHideAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: scrollHideResponse, dampingFraction: scrollHideDamping)
    }
}

/// 搜索匹配与「最近使用」持久化工具（供视图与单元测试直接验证）。
enum DockSearchSupport {
    static let recentModesStorageKey = "imink.dock.recentModes"
    static let maxRecentCount = 3

    /// 大小写不敏感、全半角不敏感、忽略所有空白字符的搜索词归一化。
    static func normalize(_ raw: String) -> String {
        raw
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .replacingOccurrences(of: "\u{3000}", with: "")
            .lowercased()
    }

    static func matches(query: String, candidates: [String]) -> Bool {
        let q = normalize(query)
        guard !q.isEmpty else { return true }
        return candidates.contains { candidate in
            normalize(candidate).contains(q)
        }
    }

    static func parseRecentKeys(_ rawStorage: String) -> [String] {
        rawStorage
            .split(separator: "|")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func recordRecentKey(_ key: String, into rawStorage: String) -> String {
        guard !key.isEmpty else { return rawStorage }
        var list = parseRecentKeys(rawStorage).filter { $0 != key }
        list.insert(key, at: 0)
        if list.count > maxRecentCount {
            list = Array(list.prefix(maxRecentCount))
        }
        return list.joined(separator: "|")
    }
}

private struct SqueezePulseTrigger: Equatable {
    var generation: Int = 0
    var isOpening: Bool = true
}

private struct SqueezeKeyframeValues {
    var widthScale: CGFloat = 1.0
}

private struct DockRowStaggerModifier: ViewModifier {
    let opacity: Double
    let offsetY: CGFloat
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(y: offsetY)
            .blur(radius: blurRadius)
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

/// 面板内可搜索、可加入「最近使用」的筛选项描述。
private struct DockPanelItem: Identifiable {
    let id: String
    let recentKey: String?
    let title: String
    let keywords: [String]
    let isSelected: Bool
    let isNavigation: Bool
    let badgeCount: Int
    let iconTint: Color
    let iconBuilder: () -> AnyView
    let action: () -> Void
}

/// 可展开底部栏（Liquid Glass 4-Tab 居中对称 + 36pt 玻璃搜索框 + 最近使用 + 键盘避让版）：
/// - 仅保留「主页 / 对战 / 鲑鱼跑 / 我」4 个等宽对称按钮；
/// - 面板标题行下方、分组之前内嵌 36pt 高玻璃底搜索框（`TextField` + `magnifyingglass` + `.textFieldStyle(.plain)` + 圆角 12，占位「搜索模式或规则」）；
/// - 支持模式名 + 规则名大小写不敏感、忽略空格实时过滤，无匹配时显示「没有匹配的筛选项」；
/// - 面板顶部支持「最近使用」分区（`@AppStorage("imink.dock.recentModes")`，最多 3 个，空时不显示）；
/// - 键盘弹出时整体上移不遮挡 Dock；点击遮罩或下滑时先收键盘再收面板。
struct ExpandingDock: View {
    @Binding var tabSelection: Int

    @ObservedObject private var dockStore = DockVisibilityStore.shared
    @EnvironmentObject private var battleViewModel: BattleListViewModel
    @EnvironmentObject private var coopViewModel: CoopListViewModel

    @AppStorage("home_page_selectedScheduleType") private var homeScheduleType: Int = 0
    @AppStorage(DockSearchSupport.recentModesStorageKey) private var recentModesStorage: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Namespace private var glassNamespace
    @Namespace private var tabSelectionNamespace

    @State private var dragOffsetY: CGFloat = 0
    @State private var squeezeTrigger = SqueezePulseTrigger()
    @State private var searchText: String = ""
    @State private var keyboardOverlap: CGFloat = 0
    @FocusState private var isSearchFocused: Bool

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

    private var isSearching: Bool {
        !DockSearchSupport.normalize(searchText).isEmpty
    }

    private var currentTotalStaggerSlots: Int {
        9
    }

    var body: some View {
        GeometryReader { proxy in
            let screenSize = proxy.size
            let safeTop = FloatingBarInsets.safeArea.top
            let safeBottom = FloatingBarInsets.safeArea.bottom
            let restingBottomMargin = DockConfig.bottomMargin(safeAreaBottom: safeBottom)
            // 键盘弹出时整组面板 + 底部 4-Tab 底座整体上移到键盘顶沿上方 8pt，绝不遮住 Dock
            let effectiveBottomMargin = (isExpanded && keyboardOverlap > 10)
                ? (keyboardOverlap + 8)
                : restingBottomMargin
            let hiddenOffset = DockConfig.collapsedHeight + restingBottomMargin + 16
            let availableAboveBottom = max(
                220,
                screenSize.height - safeTop - 10 - effectiveBottomMargin - DockConfig.collapsedHeight
            )
            let maxPanelBodyHeight = min(availableAboveBottom, 468)
            let fullPlatterWidth = min(
                max(screenSize.width - DockConfig.horizontalMargin * 2, 240),
                DockConfig.maxDockWidth
            )

            ZStack(alignment: .bottom) {
                if isExpanded {
                    backdropLayer
                }

                GlassEffectContainer(spacing: 0) {
                    morphingGlassPlatter(
                        fullPlatterWidth: fullPlatterWidth,
                        maxPanelBodyHeight: maxPanelBodyHeight
                    )
                }
                .frame(width: fullPlatterWidth, alignment: .bottom)
                .onGeometryChange(for: CGRect.self) { geo in
                    geo.frame(in: .named("expandingDockHostSpace"))
                } action: { rect in
                    if !isExpanded, rect.width > 0, rect.height > 0 {
                        DockVisibilityStore.shared.collapsedHitRect = rect
                    }
                }
                .padding(.bottom, effectiveBottomMargin)
                .offset(y: isScrollingHidden ? hiddenOffset : dragOffsetY)
                .scaleEffect(isScrollingHidden && !reduceMotion ? 0.94 : 1.0, anchor: .bottom)
                .opacity(isScrollingHidden ? 0 : 1)
                .allowsHitTesting(!isScrollingHidden)
                .onGeometryChange(for: CGFloat.self) { geo in
                    geo.size.height
                } action: { _ in
                    if !isExpanded {
                        let restingTop = restingBottomMargin + DockConfig.collapsedHeight
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
        .animation(DockMotion.transitionAnimation(to: dockStore.state, reduceMotion: envReduceMotion), value: dockStore.state)
        .onChange(of: isExpanded) { oldValue, newValue in
            guard oldValue != newValue else { return }
            if !newValue {
                dismissKeyboard()
                searchText = ""
            }
            if !reduceMotion {
                squeezeTrigger = SqueezePulseTrigger(
                    generation: squeezeTrigger.generation + 1,
                    isOpening: newValue
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let endFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
            let windowHeight = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .bounds.height ?? 874
            let overlap = max(0, windowHeight - endFrame.minY)
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: DockMotion.reducedDuration)
                    : .spring(response: 0.30, dampingFraction: 0.88)
            ) {
                keyboardOverlap = overlap
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: DockMotion.reducedDuration)
                    : .spring(response: 0.26, dampingFraction: 0.92)
            ) {
                keyboardOverlap = 0
            }
        }
        .onAppear {
            let restingTop = DockConfig.defaultCustomDockTop(safeAreaBottom: FloatingBarInsets.safeArea.bottom)
            FloatingBarInsets.measuredCustomDockTop = restingTop
        }
    }

    // MARK: - 1. 轻透背景点击遮罩（点遮罩时：若键盘已弹出则先收键盘、再收面板）

    private var backdropLayer: some View {
        Color.black
            .opacity(
                (colorScheme == .dark ? 0.22 : 0.08) * Double(max(0, 1 - dockStore.dragDismissProgress))
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboardThenCollapse()
            }
            .transition(.opacity)
            .accessibilityHidden(true)
    }

    // MARK: - 2. 居中对称连续变形毛玻璃主体（`keyframeAnimator` 水平微收腰脉冲 + 面板底边紧贴 Dock 零跳位）

    private func morphingGlassPlatter(fullPlatterWidth: CGFloat, maxPanelBodyHeight: CGFloat) -> some View {
        let platterShape = RoundedRectangle(cornerRadius: DockConfig.cornerRadius, style: .continuous)

        return VStack(spacing: 0) {
            expandedMenuSection(fullPlatterWidth: fullPlatterWidth, maxPanelBodyHeight: maxPanelBodyHeight)

            if isExpanded {
                Rectangle()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.09))
                    .frame(height: 0.6)
                    .padding(.horizontal, 12)
                    .transition(.opacity.animation(.easeOut(duration: 0.14)))
            }

            collapsedTabBarHandle
        }
        .clipShape(platterShape)
        .keyframeAnimator(initialValue: SqueezeKeyframeValues(), trigger: squeezeTrigger) { content, value in
            let factor = (reduceMotion || squeezeTrigger.generation == 0) ? 1.0 : value.widthScale
            content
                .frame(width: fullPlatterWidth * factor)
        } keyframes: { _ in
            KeyframeTrack(\.widthScale) {
                if reduceMotion || squeezeTrigger.generation == 0 {
                    LinearKeyframe(1.0, duration: 0.01)
                } else if squeezeTrigger.isOpening {
                    CubicKeyframe(DockMotion.openSqueezeScale, duration: 0.085)
                    SpringKeyframe(
                        1.0,
                        duration: 0.36,
                        spring: Spring(response: 0.30, dampingRatio: 0.80)
                    )
                } else {
                    CubicKeyframe(DockMotion.closeSqueezeScale, duration: 0.060)
                    SpringKeyframe(
                        1.0,
                        duration: 0.22,
                        spring: Spring(response: 0.20, dampingRatio: 0.94)
                    )
                }
            }
        }
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
                if isExpanded {
                    dismissKeyboardThenCollapse()
                } else {
                    Haptics.generateIfEnabled(.light)
                    withAnimation(DockMotion.openAnimation(reduceMotion: envReduceMotion)) {
                        dragOffsetY = 0
                        dockStore.expand()
                    }
                }
            } else {
                if isExpanded {
                    dismissKeyboard()
                    searchText = ""
                    withAnimation(DockMotion.closeAnimation(reduceMotion: envReduceMotion)) {
                        dragOffsetY = 0
                        dockStore.collapse()
                    }
                }
                withAnimation(DockMotion.tabAnimation(reduceMotion: envReduceMotion)) {
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

    // MARK: - 4. 展开态菜单区：标题行 -> 36pt 玻璃搜索框 -> 最近使用(可选) -> 模式/规则列表 -> 底部更多条件

    private func staggeredRowTransition(openIndex: Int) -> AnyTransition {
        if reduceMotion {
            return .opacity.animation(.easeOut(duration: DockMotion.reducedDuration))
        }
        let total = max(currentTotalStaggerSlots, 1)
        let clampedOpen = min(max(openIndex, 0), total - 1)
        let closeIndex = max(0, total - 1 - clampedOpen)
        let hiddenState = DockRowStaggerModifier(
            opacity: 0,
            offsetY: DockMotion.rowInitialOffsetY,
            blurRadius: DockMotion.rowInitialBlur
        )
        let identityState = DockRowStaggerModifier(opacity: 1, offsetY: 0, blurRadius: 0)

        return .asymmetric(
            insertion: .modifier(active: hiddenState, identity: identityState)
                .animation(
                    .spring(response: DockMotion.rowOpenResponse, dampingFraction: DockMotion.rowOpenDamping)
                        .delay(Double(clampedOpen) * DockMotion.rowOpenStaggerStep)
                ),
            removal: .modifier(active: hiddenState, identity: identityState)
                .animation(
                    .easeIn(duration: DockMotion.rowCloseItemDuration)
                        .delay(Double(closeIndex) * DockMotion.rowCloseStaggerStep)
                )
        )
    }

    private func expandedMenuSection(fullPlatterWidth: CGFloat, maxPanelBodyHeight: CGFloat) -> some View {
        let sections = resolvedVisibleSections
        let totalVisibleRows = sections.reduce(0) { $0 + $1.items.count }
        let sectionHeaderCount = sections.filter { $0.header != nil }.count
        let chromeHeight: CGFloat = 40 + 40 + (moreFilterFooterRow != nil ? 48 : 8)
        let maxListViewportHeight = max(88, min(286, maxPanelBodyHeight - chromeHeight))
        let estimatedListHeight = CGFloat(max(totalVisibleRows, 1)) * (DockConfig.panelRowHeight + 2)
            + CGFloat(sectionHeaderCount) * 22
        let shouldScroll = estimatedListHeight > maxListViewportHeight

        return VStack(alignment: .leading, spacing: isExpanded ? 5 : 0) {
            if isExpanded {
                panelGrabberAndHeader
                    .transition(staggeredRowTransition(openIndex: 8))

                // 面板标题行下方、所有分组之前：36pt 高玻璃底搜索框（圆角 12）
                dockSearchField
                    .transition(staggeredRowTransition(openIndex: 7))
            }

            if shouldScroll {
                if isExpanded {
                    ScrollView(.vertical, showsIndicators: false) {
                        panelSectionsContent(sections: sections, totalRows: totalVisibleRows)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(maxHeight: maxListViewportHeight)
                }
            } else {
                panelSectionsContent(sections: sections, totalRows: totalVisibleRows)
            }

            if isExpanded, let footer = moreFilterFooterRow {
                Rectangle()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    .frame(height: 0.6)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .transition(.opacity.animation(.easeOut(duration: 0.14)))

                footer
                    .transition(staggeredRowTransition(openIndex: 0))
            }
        }
        .padding(.horizontal, DockConfig.panelPadding)
        .padding(.top, isExpanded ? 6 : 0)
        .padding(.bottom, isExpanded ? 6 : 0)
        .frame(width: fullPlatterWidth)
    }

    // MARK: - 4.1 顶部标题把手与 36pt 玻璃搜索框

    private var panelGrabberAndHeader: some View {
        let config: (badge: String, title: String, trailing: String?, accent: Color) = {
            switch activeTab {
            case .battle:
                let status: String
                if !battleViewModel.filter.rules.isEmpty,
                   let first = battleViewModel.filter.rules.first,
                   let r = BattleRule(rawValue: first) {
                    status = (r == .turfWar) ? "涂地模式" : r.name
                } else if battleViewModel.filter.modes.isEmpty {
                    status = "全部"
                } else {
                    status = "已选 \(battleViewModel.filter.modes.count)"
                }
                return ("对战", "模式与规则筛选", status, .spOrange)
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
        .contentShape(Rectangle())
        .gesture(expandedHeaderDragGesture)
    }

    /// 规格 1：面板标题行下方、分组之前的 36pt 玻璃底搜索框（`TextField` + `magnifyingglass` + `.textFieldStyle(.plain)` + 圆角 12）。
    private var dockSearchField: some View {
        let searchShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("搜索模式或规则", text: $searchText)
                .textFieldStyle(.plain)
                .font(.appCaption)
                .foregroundStyle(Color.appLabel)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("expandingDock.searchField")

            if !searchText.isEmpty {
                Button {
                    Haptics.generateIfEnabled(.light)
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索词")
                .accessibilityIdentifier("expandingDock.searchClearButton")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background {
            if reduceTransparency {
                searchShape
                    .fill(Color(uiColor: .secondarySystemBackground))
            } else {
                searchShape
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.65 : 0.78)
            }
        }
        .overlay {
            searchShape
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.22 : 0.52),
                    lineWidth: 0.8
                )
                .allowsHitTesting(false)
        }
    }

    // MARK: - 5. 数据源组装：最近使用（最多 3 项，空时不显示）+ 模式名/规则名实时过滤 + 空结果占位

    private struct PanelSection: Identifiable {
        let id: String
        let header: String?
        let items: [DockPanelItem]
    }

    private var resolvedVisibleSections: [PanelSection] {
        if isSearching {
            let candidates = searchableCatalogForActiveTab.filter { item in
                DockSearchSupport.matches(query: searchText, candidates: [item.title] + item.keywords)
            }
            return candidates.isEmpty
                ? []
                : [PanelSection(id: "search.results", header: nil, items: candidates)]
        }

        var sections: [PanelSection] = []

        // 规格 4：「最近使用」分区（最多 3 个，存储于 @AppStorage("imink.dock.recentModes")，空时不显示这一区）
        let recents = resolvedRecentItems
        if !recents.isEmpty {
            sections.append(PanelSection(id: "section.recent", header: "最近使用", items: recents))
        }

        switch activeTab {
        case .battle:
            sections.append(
                PanelSection(
                    id: "section.battleModes",
                    header: recents.isEmpty ? "对战模式" : "全部模式",
                    items: battleModeItems
                )
            )
            sections.append(
                PanelSection(
                    id: "section.battleRules",
                    header: "对战规则",
                    items: battleRuleItems
                )
            )
        case .coop:
            sections.append(
                PanelSection(
                    id: "section.coopRules",
                    header: recents.isEmpty ? nil : "打工规则",
                    items: coopRuleItems
                )
            )
        case .home:
            sections.append(PanelSection(id: "section.home", header: nil, items: homeQuickItems))
        case .me:
            sections.append(PanelSection(id: "section.me", header: nil, items: meQuickItems))
        }
        return sections
    }

    /// 搜索时的候选池：在「对战」搜模式+对战规则；在「鲑鱼跑」搜打工规则；在「主页/我」同时支持搜全站模式与规则。
    private var searchableCatalogForActiveTab: [DockPanelItem] {
        switch activeTab {
        case .battle:
            return battleModeItems + battleRuleItems
        case .coop:
            return coopRuleItems
        case .home:
            return homeQuickItems + battleModeItems.filter { $0.id != "expandingDock.battleMode.ALL" } + battleRuleItems + coopRuleItems.filter { $0.id != "expandingDock.coopRule.ALL_RULE" }
        case .me:
            return meQuickItems + battleModeItems.filter { $0.id != "expandingDock.battleMode.ALL" } + battleRuleItems + coopRuleItems.filter { $0.id != "expandingDock.coopRule.ALL_RULE" }
        }
    }

    private var resolvedRecentItems: [DockPanelItem] {
        let keys = DockSearchSupport.parseRecentKeys(recentModesStorage)
        guard !keys.isEmpty else { return [] }
        let lookupPool = battleModeItems + battleRuleItems + coopRuleItems
        var resolved: [DockPanelItem] = []
        for key in keys {
            guard let base = lookupPool.first(where: { $0.recentKey == key }) else { continue }
            // 在对战页只展示对战最近项、在打工页只展示打工最近项，主页/我展示跨页最近项，保证语义干净直观
            if activeTab == .battle && !key.hasPrefix("battle") { continue }
            if activeTab == .coop && !key.hasPrefix("coop") { continue }
            resolved.append(
                DockPanelItem(
                    id: "expandingDock.recent.\(key)",
                    recentKey: base.recentKey,
                    title: base.title,
                    keywords: base.keywords,
                    isSelected: base.isSelected,
                    isNavigation: false,
                    badgeCount: 0,
                    iconTint: base.iconTint,
                    iconBuilder: base.iconBuilder,
                    action: base.action
                )
            )
            if resolved.count >= DockSearchSupport.maxRecentCount { break }
        }
        return resolved
    }

    @ViewBuilder
    private func panelSectionsContent(sections: [PanelSection], totalRows: Int) -> some View {
        VStack(alignment: .leading, spacing: isExpanded ? 2 : 0) {
            if isExpanded {
                if sections.isEmpty && isSearching {
                    // 规格 2：无搜索结果时显示一行「没有匹配的筛选项」
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: DockConfig.panelIconSize, height: DockConfig.panelIconSize)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text("没有匹配的筛选项")
                            .font(.appBody)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: DockConfig.panelRowHeight)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("没有匹配的筛选项")
                    .accessibilityIdentifier("expandingDock.searchEmptyState")
                    .transition(.opacity.animation(.easeOut(duration: 0.16)))
                } else {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { secIdx, section in
                        if let header = section.header {
                            Text(header)
                                .font(.appSubCaptionMono)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.top, secIdx == 0 ? 2 : 6)
                                .padding(.bottom, 1)
                                .accessibilityIdentifier("expandingDock.section.\(section.id)")
                                .transition(.opacity.animation(.easeOut(duration: 0.14)))
                        }

                        ForEach(Array(section.items.enumerated()), id: \.element.id) { itemIdx, item in
                            let openIdx = max(1, min(6, totalRows - itemIdx))
                            renderPanelItem(item)
                                .transition(staggeredRowTransition(openIndex: openIdx))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderPanelItem(_ item: DockPanelItem) -> some View {
        if item.isNavigation {
            dockNavigationRow(
                id: item.id,
                title: item.title,
                tint: item.iconTint,
                badgeCount: item.badgeCount,
                icon: item.iconBuilder,
                action: item.action
            )
        } else {
            dockSelectableRow(
                id: item.id,
                title: item.title,
                isSelected: item.isSelected,
                iconTint: item.iconTint,
                icon: item.iconBuilder,
                action: item.action
            )
        }
    }

    // MARK: - 5.1 对战模式项 + 对战规则项

    private var battleModeItems: [DockPanelItem] {
        BattleMode.allCases.map { mode in
            let isSelected = battleViewModel.filter.rules.isEmpty && (
                mode == .all
                    ? battleViewModel.filter.modes.isEmpty
                    : battleViewModel.filter.modes.contains(mode.rawValue)
            )
            let extraKeywords: [String] = {
                switch mode {
                case .all: return ["全部对战", "all"]
                case .regular: return ["一般比赛", "常规比赛", "涂地", "占地", "regular", "turfwar"]
                case .anarchy: return ["蛮颓比赛", "真格比赛", "挑战", "开放", "bankara", "anarchy"]
                case .xMatch: return ["X比赛", "X比赛系列", "xmatch", "x"]
                case .league: return ["活动比赛", "活动", "league", "event"]
                case .privateMatch: return ["私人比赛", "私房", "private"]
                case .fest: return ["祭典比赛", "祭典", "splatfest", "fest"]
                }
            }()
            let recentKey: String? = (mode == .all) ? nil : "battleMode:\(mode.rawValue)"

            return DockPanelItem(
                id: "expandingDock.battleMode.\(mode.rawValue)",
                recentKey: recentKey,
                title: mode.name,
                keywords: extraKeywords,
                isSelected: isSelected,
                isNavigation: false,
                badgeCount: 0,
                iconTint: mode.color,
                iconBuilder: {
                    if mode == .all {
                        return AnyView(
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.accentColor : .spOrange)
                        )
                    } else {
                        return AnyView(
                            mode.icon
                                .resizable()
                                .scaledToFit()
                                .frame(width: 17, height: 17)
                        )
                    }
                },
                action: {
                    if let recentKey {
                        recordRecentSelection(recentKey)
                    }
                    selectModeAndAutoCollapse {
                        if tabSelection != DockTab.battle.rawValue {
                            tabSelection = DockTab.battle.rawValue
                        }
                        await battleViewModel.selectModeFromDock(mode)
                    }
                }
            )
        }
    }

    private var battleRuleItems: [DockPanelItem] {
        BattleRule.allCases.map { rule in
            let isSelected = battleViewModel.filter.modes.isEmpty
                && battleViewModel.filter.rules.contains(rule.rawValue)
            let displayTitle: String = (rule == .turfWar) ? "涂地模式" : rule.name
            let ruleTint: Color = {
                switch rule {
                case .turfWar: return .spLightGreen
                case .splatZones, .towerControl, .rainmaker, .clamBlitz: return .spOrange
                case .triColor: return .spPurple
                }
            }()
            let extraKeywords: [String] = {
                switch rule {
                case .turfWar: return ["涂地模式", "涂地", "占地对战", "占地", "turfwar", "tw"]
                case .splatZones: return ["真格区域", "区域", "占地真格", "splatzones", "area", "sz"]
                case .towerControl: return ["真格塔楼", "塔楼", "推塔", "towercontrol", "loft", "tc"]
                case .rainmaker: return ["真格鱼虎", "真格鱼虎对战", "鱼虎", "抢鱼", "rainmaker", "goal", "rm"]
                case .clamBlitz: return ["真格蛤蜊", "蛤蜊", "投蛤", "clamblitz", "clam", "cb"]
                case .triColor: return ["三色夺宝对战", "三色", "三色夺宝", "tricolor"]
                }
            }()
            let recentKey = "battleRule:\(rule.rawValue)"

            return DockPanelItem(
                id: "expandingDock.battleRule.\(rule.rawValue)",
                recentKey: recentKey,
                title: displayTitle,
                keywords: [rule.name] + extraKeywords,
                isSelected: isSelected,
                isNavigation: false,
                badgeCount: 0,
                iconTint: ruleTint,
                iconBuilder: {
                    AnyView(
                        rule.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                    )
                },
                action: {
                    recordRecentSelection(recentKey)
                    selectModeAndAutoCollapse {
                        if tabSelection != DockTab.battle.rawValue {
                            tabSelection = DockTab.battle.rawValue
                        }
                        await battleViewModel.selectRuleFromDock(rule)
                    }
                }
            )
        }
    }

    // MARK: - 5.2 鲑鱼跑规则项

    private var coopRuleItems: [DockPanelItem] {
        var list: [DockPanelItem] = CoopRule.allCases.map { rule in
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
            let keywords: [String] = {
                switch rule {
                case .ALL: return ["全部打工", "all"]
                case .REGULAR: return ["鲑鱼跑", "常规打工", "打工", "salmonrun", "regular"]
                case .BIG_RUN: return ["大型跑", "bigrun"]
                case .TEAM_CONTEST: return ["团队打工竞赛", "团队竞赛", "打工竞赛", "eggstrawork", "teamcontest"]
                }
            }()
            let recentKey: String? = (rule == .ALL) ? nil : "coopRule:\(rule.rawValue)"

            return DockPanelItem(
                id: "expandingDock.coopRule.\(rule.rawValue)",
                recentKey: recentKey,
                title: rule.name,
                keywords: keywords,
                isSelected: isSelected,
                isNavigation: false,
                badgeCount: 0,
                iconTint: ruleColor,
                iconBuilder: {
                    if rule == .ALL {
                        return AnyView(
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.accentColor : .spGreen)
                        )
                    } else {
                        return AnyView(
                            rule.icon
                                .resizable()
                                .scaledToFit()
                                .frame(width: 17, height: 17)
                        )
                    }
                },
                action: {
                    if let recentKey {
                        recordRecentSelection(recentKey)
                    }
                    selectModeAndAutoCollapse {
                        if tabSelection != DockTab.coop.rawValue {
                            tabSelection = DockTab.coop.rawValue
                        }
                        await coopViewModel.selectRuleFromDock(rule)
                    }
                }
            )
        }

        list.append(
            DockPanelItem(
                id: "expandingDock.coopRule.SHIFT_CARDS",
                recentKey: "coopMode:SHIFT_CARDS",
                title: "打工卡片",
                keywords: ["打工卡片", "班次卡片", "shiftcards", "cards"],
                isSelected: coopViewModel.isShowingShiftCards,
                isNavigation: false,
                badgeCount: 0,
                iconTint: .spYellow,
                iconBuilder: {
                    AnyView(
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(coopViewModel.isShowingShiftCards ? Color.accentColor : .spYellow)
                    )
                },
                action: {
                    recordRecentSelection("coopMode:SHIFT_CARDS")
                    selectModeAndAutoCollapse {
                        if tabSelection != DockTab.coop.rawValue {
                            tabSelection = DockTab.coop.rawValue
                        }
                        await coopViewModel.selectShiftCardsFromDock()
                    }
                }
            )
        )
        return list
    }

    // MARK: - 5.3 主页与「我」页快捷项

    private var homeQuickItems: [DockPanelItem] {
        [
            DockPanelItem(
                id: "expandingDock.home.battleSchedule",
                recentKey: nil,
                title: "对战日程",
                keywords: ["对战日程", "日程", "schedule", "battle"],
                isSelected: homeScheduleType == 0,
                isNavigation: false,
                badgeCount: 0,
                iconTint: .spOrange,
                iconBuilder: {
                    AnyView(Image(.anarchy).resizable().scaledToFit().frame(width: 17, height: 17))
                },
                action: {
                    selectModeAndAutoCollapse { homeScheduleType = 0 }
                }
            ),
            DockPanelItem(
                id: "expandingDock.home.coopSchedule",
                recentKey: nil,
                title: "鲑鱼跑日程",
                keywords: ["鲑鱼跑日程", "打工日程", "salmonrun", "coop"],
                isSelected: homeScheduleType == 1,
                isNavigation: false,
                badgeCount: 0,
                iconTint: .spGreen,
                iconBuilder: {
                    AnyView(Image(.salmonRun).resizable().scaledToFit().frame(width: 17, height: 17))
                },
                action: {
                    selectModeAndAutoCollapse { homeScheduleType = 1 }
                }
            ),
            DockPanelItem(
                id: "expandingDock.home.gotoBattleFilter",
                recentKey: nil,
                title: "去对战筛选页设置条件…",
                keywords: ["对战筛选", "更多条件"],
                isSelected: false,
                isNavigation: true,
                badgeCount: battleViewModel.extraActiveFilterCount,
                iconTint: .spOrange,
                iconBuilder: {
                    AnyView(
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.spOrange)
                    )
                },
                action: {
                    closeAndPerform {
                        tabSelection = DockTab.battle.rawValue
                        battleViewModel.showFilterSheet = true
                    }
                }
            ),
            DockPanelItem(
                id: "expandingDock.home.gotoCoopFilter",
                recentKey: nil,
                title: "去打工筛选页设置条件…",
                keywords: ["打工筛选", "更多条件"],
                isSelected: false,
                isNavigation: true,
                badgeCount: coopViewModel.extraActiveFilterCount,
                iconTint: .spGreen,
                iconBuilder: {
                    AnyView(
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.spGreen)
                    )
                },
                action: {
                    closeAndPerform {
                        tabSelection = DockTab.coop.rawValue
                        coopViewModel.showFilterSheet = true
                    }
                }
            ),
        ]
    }

    private var meQuickItems: [DockPanelItem] {
        [
            ("expandingDock.me.weapon", "武器榜", ["武器榜", "weapon"], "scope", Color.spOrange, "weapon"),
            ("expandingDock.me.stage", "场地榜", ["场地榜", "地图", "stage"], "map.fill", Color.spLightGreen, "stage"),
            ("expandingDock.me.coop", "打工记录统计", ["打工记录统计", "统计", "coop"], "drop.fill", Color.spGreen, "coop"),
            ("expandingDock.me.trash", "记录回收站", ["回收站", "已删除", "trash"], "trash.fill", Color.spPink, "trash"),
            ("expandingDock.me.settings", "账号与偏好设置", ["设置", "偏好", "settings"], "gearshape.fill", Color.accentColor, "settings"),
        ].map { id, title, kw, symbol, tint, dest in
            DockPanelItem(
                id: id,
                recentKey: nil,
                title: title,
                keywords: kw,
                isSelected: false,
                isNavigation: true,
                badgeCount: 0,
                iconTint: tint,
                iconBuilder: {
                    AnyView(
                        Image(systemName: symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                    )
                },
                action: {
                    closeAndPerform { dockStore.meDestination = dest }
                }
            )
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
                    tint: .spOrange,
                    badgeCount: battleViewModel.extraActiveFilterCount,
                    icon: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.spOrange)
                    }
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
                    tint: .spGreen,
                    badgeCount: coopViewModel.extraActiveFilterCount,
                    icon: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.spGreen)
                    }
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

    // MARK: - 6. 透明毛玻璃行组件（统一 40pt 行高、28pt 图标块；单选行只显示 ✓ 不显示 ›）

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

    private func dockNavigationRow<Icon: View>(
        id: String,
        title: String,
        tint: Color,
        badgeCount: Int,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
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

    // MARK: - 7. 交互式手势驱动（下滑时若键盘弹出则先收键盘、再收面板）

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
                let shouldClose = dy > 56 || predictedY > 110
                if shouldClose {
                    dismissKeyboardThenCollapse()
                } else {
                    withAnimation(DockMotion.openAnimation(reduceMotion: envReduceMotion)) {
                        dragOffsetY = 0
                        dockStore.dragDismissProgress = 0
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
                    let shouldClose = abs(dy) > abs(dx) * 1.2 && (dy > 44 || predictedY > 100)
                    if shouldClose {
                        dismissKeyboardThenCollapse()
                    } else {
                        withAnimation(DockMotion.openAnimation(reduceMotion: envReduceMotion)) {
                            dragOffsetY = 0
                            dockStore.dragDismissProgress = 0
                        }
                    }
                } else if abs(dy) > abs(dx) * 1.4 && dy < -32 {
                    Haptics.generateIfEnabled(.light)
                    withAnimation(DockMotion.openAnimation(reduceMotion: envReduceMotion)) {
                        dockStore.expand()
                    }
                }
            }
    }

    // MARK: - 8. 键盘先行收起、最近使用记录与单选自动收起辅助

    private func recordRecentSelection(_ key: String) {
        recentModesStorage = DockSearchSupport.recordRecentKey(key, into: recentModesStorage)
    }

    private func dismissKeyboard() {
        isSearchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// 规格 3：点击遮罩或下滑时，若键盘正处于弹出态，先触发收键盘，再在 130ms 后触发收面板，杜绝键盘与面板打架。
    private func dismissKeyboardThenCollapse() {
        Haptics.generateIfEnabled(.light)
        let hadKeyboard = isSearchFocused || keyboardOverlap > 10
        if hadKeyboard {
            dismissKeyboard()
            withAnimation(DockMotion.openAnimation(reduceMotion: envReduceMotion)) {
                dragOffsetY = 0
                dockStore.dragDismissProgress = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(DockMotion.closeAnimation(reduceMotion: envReduceMotion)) {
                    searchText = ""
                    dockStore.collapse()
                }
            }
        } else {
            withAnimation(DockMotion.closeAnimation(reduceMotion: envReduceMotion)) {
                dragOffsetY = 0
                dockStore.dragDismissProgress = 0
                searchText = ""
                dockStore.collapse()
            }
        }
    }

    private func selectModeAndAutoCollapse(_ work: @escaping () async -> Void) {
        Haptics.generateIfEnabled(.selectionChanged)
        let hadKeyboard = isSearchFocused || keyboardOverlap > 10
        if hadKeyboard {
            dismissKeyboard()
        }
        Task { @MainActor in
            await work()
            try? await Task.sleep(for: .milliseconds(hadKeyboard ? 110 : 80))
            withAnimation(DockMotion.closeAnimation(reduceMotion: envReduceMotion)) {
                dragOffsetY = 0
                searchText = ""
                dockStore.collapse()
            }
        }
    }

    private func closeAndPerform(_ block: @escaping () -> Void) {
        Haptics.generateIfEnabled(.light)
        dismissKeyboard()
        withAnimation(DockMotion.closeAnimation(reduceMotion: envReduceMotion)) {
            dragOffsetY = 0
            searchText = ""
            dockStore.collapse()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
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
