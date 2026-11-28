import Combine
import Observation
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// 可展开底部栏动效常量与辅助工具（供 SwiftUI 侧状态同步与无障碍降级共享）。
enum DockMotion {
    static let expandDuration: TimeInterval = 0.35
    static let expandDamping: CGFloat = 0.72
    static let collapseDuration: TimeInterval = 0.25
    static let collapseDamping: CGFloat = 0.94
    static let reducedDuration: TimeInterval = 0.18

    static func isReduceMotionActive(_ environmentReduceMotion: Bool = false) -> Bool {
        UIAccessibility.isReduceMotionEnabled || environmentReduceMotion
    }

    static func openAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: expandDuration, dampingFraction: Double(expandDamping))
    }

    static func closeAnimation(reduceMotion: Bool) -> Animation {
        isReduceMotionActive(reduceMotion)
            ? .easeOut(duration: reducedDuration)
            : .spring(response: collapseDuration, dampingFraction: Double(collapseDamping))
    }

    static func transitionAnimation(to state: DockState, reduceMotion: Bool) -> Animation {
        switch state {
        case .expanded:
            return openAnimation(reduceMotion: reduceMotion)
        case .collapsed, .scrollingHidden:
            return closeAnimation(reduceMotion: reduceMotion)
        }
    }
}

/// 保留搜索归一化与最近使用工具以兼容已有单测与外部调用。
enum DockSearchSupport {
    static let recentModesStorageKey = "imink.dock.recentModes"
    static let maxRecentCount = 3

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

/// 四个一级根 Tab 定义（图标取项目 PDF 模板矢量资源，标题走本地化 key）。
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

    /// 仅「对战」与「鲑鱼跑」支持二次点击展开单物体模式快筛菜单。
    var supportsFilterMenu: Bool {
        self == .battle || self == .coop
    }
}

/// 单物体变形收起交接与详情页保护的纯逻辑判定（便于单元测试覆盖）。
enum DockMorphHandoffPolicy {
    static let maxHeightError: CGFloat = 1.0
    static let minScaleX: CGFloat = 0.99
    static let maxScaleX: CGFloat = 1.01
    static let maxSettlingVelocity: CGFloat = 45.0
    static let minClosingElapsed: CFTimeInterval = 0.10
    static let maxClosingElapsed: CFTimeInterval = 0.34

    /// 当收起动画几何贴近真实 `UITabBar` 胶囊（高度误差 ≤ 1.0pt 且水平收腰回到 0.99~1.01）时，
    /// 立即在同一帧无感交接回真实 `UITabBar`，避免等待 400ms+ 亚像素弹簧长尾。
    static func shouldHandoffToSystemTabBar(
        isOpen: Bool,
        closingElapsed: CFTimeInterval,
        currentHeight: CGFloat,
        targetHeight: CGFloat,
        currentVelocity: CGFloat,
        scaleX: CGFloat
    ) -> Bool {
        guard !isOpen else { return false }
        if closingElapsed >= maxClosingElapsed {
            return true
        }
        guard closingElapsed >= minClosingElapsed else { return false }
        let heightError = abs(currentHeight - targetHeight)
        return heightError <= maxHeightError
            && scaleX >= minScaleX
            && scaleX <= maxScaleX
            && abs(currentVelocity) < maxSettlingVelocity
    }

    /// 仅当当前 Tab 支持快筛、处于根列表页（无二级详情 push、无转场动画、无模态弹窗）且底栏处于完整 4-Tab 静止态时允许展开。
    static func canExpandFilterMenu(
        tab: DockTab,
        navigationStackDepths: [Int],
        hasActiveTransition: Bool,
        hasPresentedModal: Bool,
        platterWidth: CGFloat,
        containerWidth: CGFloat,
        tabBarHidden: Bool
    ) -> Bool {
        guard tab.supportsFilterMenu else { return false }
        guard !tabBarHidden, !hasActiveTransition, !hasPresentedModal else { return false }
        guard navigationStackDepths.allSatisfy({ $0 <= 1 }) else { return false }
        guard containerWidth > 0, platterWidth >= containerWidth * 0.68 else { return false }
        return true
    }
}

// MARK: - SwiftUI Representable 桥接入口

/// 单物体变形底导宿主：
/// - 静止态为 iOS 26 原生 62pt Liquid Glass 4-Tab `UITabBarController`；
/// - 在根列表页二次点击「对战」或「鲑鱼跑」时，单块 `UIGlassEffect(.regular)` 胶囊原地向上长成极简扁平筛选菜单；
/// - 变形容器内置实时 4-Tab 过渡层（零 `drawHierarchy` 离屏快照）并在收起落定瞬间（~240–260ms）同帧交接回真实 `UITabBar`。
struct ExpandingDockHost: UIViewControllerRepresentable {
    @Binding var tabSelection: Int

    func makeUIViewController(context: Context) -> DockShellTabBarController {
        DockShellTabBarController(initialSelection: tabSelection) { nextIndex in
            if tabSelection != nextIndex {
                tabSelection = nextIndex
            }
        }
    }

    func updateUIViewController(_ uiViewController: DockShellTabBarController, context: Context) {
        uiViewController.syncExternalSelection(tabSelection)
    }
}

// MARK: - 1. 根容器 DockShellTabBarController（原生 UITabBarController + 单物体变形覆盖层）

@MainActor
final class DockShellTabBarController: UIViewController, UITabBarControllerDelegate, UIGestureRecognizerDelegate {
    let systemBar = UITabBarController()
    let overflowMenu = DockMorphOverflowView()

    private let backdropBlur = UIVisualEffectView(effect: nil)
    private var builtTabs: [UITab] = []
    private var currentIndex: Int
    private let onSelectionChange: (Int) -> Void
    private var cancellables = Set<AnyCancellable>()

    private var restingPlatterFrame: CGRect?
    private var restingSlotMetrics: DockRestingTabBarMetrics = .fallback(width: 350, height: 62)
    private var touchDownSelectedSlot: Int?
    private var handledReTapInDelegate = false
    private var lastToggleTimestamp: CFTimeInterval = 0

    init(initialSelection: Int, onSelectionChange: @escaping (Int) -> Void) {
        self.currentIndex = min(max(initialSelection, 0), DockTab.allCases.count - 1)
        self.onSelectionChange = onSelectionChange
        super.init(nibName: nil, bundle: nil)

        let mainVM = MainViewModel.shared
        self.builtTabs = DockTab.allCases.map { dockTab in
            let icon = UIImage(named: dockTab.iconName)?.withRenderingMode(.alwaysTemplate)
            let tab = UITab(
                title: dockTab.localizedTitle,
                image: icon,
                identifier: "expandingDock.tab.\(dockTab.rawValue)"
            ) { _ in
                let baseView: AnyView
                switch dockTab {
                case .home:
                    baseView = AnyView(HomePage(viewModel: HomeViewModel()))
                case .battle:
                    baseView = AnyView(BattleListView())
                case .coop:
                    baseView = AnyView(CoopListView())
                case .me:
                    baseView = AnyView(MePage())
                }
                let rootView = baseView
                    .environmentObject(mainVM)
                    .environmentObject(BattleListViewModel.shared)
                    .environmentObject(CoopListViewModel.shared)
                    .environmentObject(BackgroundTaskManager.shared)
                    .environmentObject(NotificationManager.shared)
                    .environmentObject(ScheduleSubscriptionManager.shared)
                    .appGameTypography()
                    .appLineHeight()
                let host = UIHostingController(rootView: rootView)
                host.view.backgroundColor = .clear
                return host
            }
            tab.accessibilityLabel = dockTab.localizedTitle
            tab.accessibilityIdentifier = "expandingDock.tab.\(dockTab.rawValue)"
            return tab
        }

        systemBar.tabs = builtTabs
        systemBar.selectedTab = builtTabs[self.currentIndex]
        systemBar.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        addChild(systemBar)
        systemBar.view.frame = view.bounds
        systemBar.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        systemBar.tabBarMinimizeBehavior = .never
        view.addSubview(systemBar.view)
        systemBar.didMove(toParent: self)

        backdropBlur.frame = view.bounds
        backdropBlur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropBlur.isUserInteractionEnabled = false
        backdropBlur.alpha = 0
        view.addSubview(backdropBlur)

        overflowMenu.frame = view.bounds
        overflowMenu.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overflowMenu.onVisibilityChange = { [weak self] visible in
            guard let self else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.systemBar.tabBar.alpha = visible ? 0 : 1
            if !visible {
                self.backdropBlur.alpha = 0
                self.backdropBlur.effect = nil
            }
            CATransaction.commit()
            if visible {
                DockVisibilityStore.shared.expand()
            } else {
                DockVisibilityStore.shared.collapse()
            }
        }
        overflowMenu.onProgressChange = { [weak self] progress in
            guard let self else { return }
            if progress > 0.01 && self.backdropBlur.effect == nil {
                self.backdropBlur.effect = UIBlurEffect(style: .systemUltraThinMaterial)
            }
            self.backdropBlur.alpha = min(1, max(0, progress * 0.55))
            if progress <= 0.005 {
                self.backdropBlur.effect = nil
            }
        }
        overflowMenu.onPick = { [weak self] pickedID in
            self?.handlePickedItem(pickedID)
        }
        overflowMenu.onNavigationGuardCheck = { [weak self] in
            guard let self else { return true }
            return self.isSelectedTabAtRootForMenu()
        }
        view.addSubview(overflowMenu)

        let touchObserver = DockTouchObserverRecognizer()
        touchObserver.cancelsTouchesInView = false
        touchObserver.delaysTouchesBegan = false
        touchObserver.delaysTouchesEnded = false
        touchObserver.delegate = self
        touchObserver.onBegan = { [weak self] point in
            self?.handleRawTouchBegan(at: point)
        }
        touchObserver.onMoved = { [weak self] point in
            self?.handleRawTouchMoved(at: point)
        }
        touchObserver.onEnded = { [weak self] point in
            self?.handleRawTouchEnded(at: point)
        }
        touchObserver.onCancelled = { [weak self] in
            self?.handleRawTouchCancelled()
        }
        view.addGestureRecognizer(touchObserver)

        bindExternalState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if systemBar.view.frame != view.bounds {
            systemBar.view.frame = view.bounds
        }
        if backdropBlur.frame != view.bounds {
            backdropBlur.frame = view.bounds
        }
        if overflowMenu.frame != view.bounds {
            overflowMenu.frame = view.bounds
        }

        if overflowMenu.isActive {
            // 若外部路由触发详情 push/pop 或弹出模态页，立刻干净收起并恢复真实 tabBar
            if !isSelectedTabAtRootForMenu() {
                overflowMenu.forceCollapseImmediate()
            }
        } else {
            cacheRestingBarGeometry()
        }

        if view.subviews.last !== overflowMenu {
            view.bringSubviewToFront(backdropBlur)
            view.bringSubviewToFront(overflowMenu)
        }
    }

    func syncExternalSelection(_ index: Int) {
        let clamped = min(max(index, 0), builtTabs.count - 1)
        guard clamped != currentIndex else { return }
        if overflowMenu.isActive {
            overflowMenu.forceCollapseImmediate()
        }
        currentIndex = clamped
        if systemBar.selectedTab !== builtTabs[clamped] {
            systemBar.selectedTab = builtTabs[clamped]
        }
    }

    private func bindExternalState() {
        DockVisibilityStore.shared.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                if state == .collapsed, self.overflowMenu.isOpen {
                    self.overflowMenu.close()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 详情页 Push / 转场保护

    private func activeTabViewController() -> UIViewController? {
        if let tabVC = systemBar.selectedTab?.viewController {
            return tabVC
        }
        return systemBar.selectedViewController
    }

    private func findNavigationControllers(in root: UIViewController?) -> [UINavigationController] {
        guard let root else { return [] }
        var result: [UINavigationController] = []
        if let nav = root as? UINavigationController {
            result.append(nav)
        }
        for child in root.children {
            result.append(contentsOf: findNavigationControllers(in: child))
        }
        return result
    }

    private func isSelectedTabAtRootForMenu() -> Bool {
        let activeTab = DockTab(rawValue: currentIndex) ?? .home
        let rootVC = activeTabViewController()
        let navs = findNavigationControllers(in: rootVC)
        let depths = navs.map { $0.viewControllers.count }
        let hasTransition = navs.contains { $0.transitionCoordinator != nil }
            || (systemBar.transitionCoordinator != nil)
        let hasModal = (systemBar.presentedViewController != nil)
            || (rootVC?.presentedViewController != nil)
            || navs.contains { $0.presentedViewController != nil }
        let platterWidth = restingPlatterFrame?.width ?? 0
        return DockMorphHandoffPolicy.canExpandFilterMenu(
            tab: activeTab,
            navigationStackDepths: depths,
            hasActiveTransition: hasTransition,
            hasPresentedModal: hasModal,
            platterWidth: platterWidth,
            containerWidth: view.bounds.width,
            tabBarHidden: systemBar.tabBar.isHidden
        )
    }

    // MARK: - UITabBarControllerDelegate

    func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
        guard let tappedIndex = builtTabs.firstIndex(where: { $0 === tab }) else { return true }
        if overflowMenu.isActive {
            if CACurrentMediaTime() - lastToggleTimestamp > 0.18 {
                lastToggleTimestamp = CACurrentMediaTime()
                overflowMenu.close()
            }
            return false
        }

        if tabBarController.selectedTab === tab || tappedIndex == currentIndex {
            cacheRestingBarGeometry()
            guard isSelectedTabAtRootForMenu() else {
                // 处于详情页或非快筛 Tab：交回系统原生行为（如二次点击返回根列表）
                return true
            }
            handledReTapInDelegate = true
            openOverflowForCurrentTab(tracking: false, at: nil)
            return false
        }

        currentIndex = tappedIndex
        onSelectionChange(tappedIndex)
        return true
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelectTab selectedTab: UITab,
        previousTab: UITab?
    ) {
        guard let tappedIndex = builtTabs.firstIndex(where: { $0 === selectedTab }) else { return }
        if previousTab === selectedTab {
            if overflowMenu.isActive {
                if CACurrentMediaTime() - lastToggleTimestamp > 0.18 {
                    lastToggleTimestamp = CACurrentMediaTime()
                    overflowMenu.close()
                }
            } else {
                cacheRestingBarGeometry()
                if isSelectedTabAtRootForMenu() {
                    handledReTapInDelegate = true
                    openOverflowForCurrentTab(tracking: false, at: nil)
                }
            }
            return
        }
        currentIndex = tappedIndex
        onSelectionChange(tappedIndex)
    }

    // MARK: - 被动原始触摸观测（兜底二次轻触 + 按住直接上滑悬停选行）

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private func handleRawTouchBegan(at point: CGPoint) {
        handledReTapInDelegate = false
        guard !overflowMenu.isActive else {
            touchDownSelectedSlot = nil
            return
        }
        cacheRestingBarGeometry()
        if let selected = systemBar.selectedTab,
           let liveIdx = builtTabs.firstIndex(where: { $0 === selected }) {
            currentIndex = liveIdx
        }
        guard isSelectedTabAtRootForMenu(),
              let platter = restingPlatterFrame,
              platter.insetBy(dx: -10, dy: -20).contains(point) else {
            touchDownSelectedSlot = nil
            return
        }
        let slotWidth = platter.width / CGFloat(max(builtTabs.count, 1))
        let slot = min(max(Int((point.x - platter.minX) / max(slotWidth, 1)), 0), builtTabs.count - 1)
        touchDownSelectedSlot = (slot == currentIndex) ? slot : nil
    }

    private func handleRawTouchMoved(at point: CGPoint) {
        if let slot = touchDownSelectedSlot, slot == currentIndex, !overflowMenu.isActive {
            if let platter = restingPlatterFrame, platter.minY - point.y > 18 {
                touchDownSelectedSlot = nil
                guard isSelectedTabAtRootForMenu() else { return }
                openOverflowForCurrentTab(tracking: true, at: point)
            }
        } else if overflowMenu.isOpen && overflowMenu.isTracking {
            overflowMenu.updateTracking(at: point)
        }
    }

    private func handleRawTouchEnded(at point: CGPoint) {
        let capturedSlot = touchDownSelectedSlot
        touchDownSelectedSlot = nil
        if overflowMenu.isOpen && overflowMenu.isTracking {
            handledReTapInDelegate = false
            overflowMenu.endTracking(at: point)
            return
        }
        // 延迟一拍等待 UITabBarControllerDelegate.shouldSelectTab 先执行，防止同一次抬手重复翻转
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            defer { self.handledReTapInDelegate = false }
            if let slot = capturedSlot,
               slot == self.currentIndex,
               !self.handledReTapInDelegate,
               !self.overflowMenu.isActive,
               CACurrentMediaTime() - self.lastToggleTimestamp > 0.18,
               self.isSelectedTabAtRootForMenu(),
               let platter = self.restingPlatterFrame,
               platter.insetBy(dx: -16, dy: -22).contains(point) {
                self.openOverflowForCurrentTab(tracking: false, at: point)
            }
        }
    }

    private func handleRawTouchCancelled() {
        touchDownSelectedSlot = nil
        handledReTapInDelegate = false
        if overflowMenu.isOpen && overflowMenu.isTracking {
            overflowMenu.cancelTracking()
        }
    }

    // MARK: - 精确测量系统 UITabBar 浮动胶囊与 4 个 Tab 槽位几何

    private func cacheRestingBarGeometry() {
        guard systemBar.isViewLoaded, view.bounds.width > 0 else { return }
        let tabBar = systemBar.tabBar
        guard !tabBar.isHidden, tabBar.alpha > 0.05 else { return }

        var detectedPlatter: CGRect?
        var bestEffectPlatter: CGRect?

        func scanPlatter(in current: UIView) {
            for sub in current.subviews where !sub.isHidden && sub.alpha > 0.05 {
                let rect = sub.convert(sub.bounds, to: view)
                let isCapsuleSized = rect.minY >= view.bounds.height - 120
                    && rect.width >= view.bounds.width * 0.65
                    && rect.width <= view.bounds.width - 16
                    && rect.height >= 48
                    && rect.height <= 72

                if isCapsuleSized {
                    let typeName = String(describing: type(of: sub))
                    if sub is UIVisualEffectView || typeName.contains("Platter") || typeName.contains("Glass") {
                        bestEffectPlatter = rect
                    }
                    if let existing = detectedPlatter {
                        if rect.width <= existing.width + 0.5 && rect.height <= existing.height + 0.5 {
                            detectedPlatter = rect
                        }
                    } else {
                        detectedPlatter = rect
                    }
                }
                scanPlatter(in: sub)
            }
        }
        scanPlatter(in: tabBar)

        let fallbackPlatter = CGRect(
            x: 21,
            y: max(0, view.bounds.height - max(view.safeAreaInsets.bottom - 13, 21) - 62),
            width: max(240, view.bounds.width - 42),
            height: 62
        )
        let platter = bestEffectPlatter ?? detectedPlatter ?? fallbackPlatter
        restingPlatterFrame = platter
        restingSlotMetrics = measureTabSlotMetrics(in: tabBar, platterInRoot: platter)

        let barTopFromBottom = max(0, view.bounds.height - platter.minY)
        if barTopFromBottom > 40, abs(FloatingBarInsets.measuredCustomDockTop - barTopFromBottom) > 0.5 {
            FloatingBarInsets.measuredCustomDockTop = barTopFromBottom
        }
        DockVisibilityStore.shared.collapsedHitRect = platter
    }

    /// 扫描真实 `UITabBar` 内部 4 个按钮（及其图标与文字）在胶囊局部坐标中的精确位置，
    /// 使 `DockMorphTabsLayer` 与真实 `UITabBar` 达到 1:1 坐标对齐；扫描不到时退回 iOS 26 标准 4pt 缩进等分槽位。
    private func measureTabSlotMetrics(in tabBar: UIView, platterInRoot: CGRect) -> DockRestingTabBarMetrics {
        let count = DockTab.allCases.count
        let expectedSlotW = platterInRoot.width / CGFloat(count)

        var buttonCandidates: [(rect: CGRect, view: UIView)] = []
        func scanButtons(in current: UIView) {
            for sub in current.subviews where !sub.isHidden && sub.alpha > 0.05 {
                let r = sub.convert(sub.bounds, to: view)
                let insidePlatter = r.minX >= platterInRoot.minX - 2
                    && r.maxX <= platterInRoot.maxX + 2
                    && r.minY >= platterInRoot.minY - 2
                    && r.maxY <= platterInRoot.maxY + 2
                let isSlotSized = r.width >= expectedSlotW * 0.72
                    && r.width <= expectedSlotW * 1.15
                    && r.height >= platterInRoot.height * 0.65
                    && r.height <= platterInRoot.height + 2
                if insidePlatter && isSlotSized {
                    let typeName = String(describing: type(of: sub))
                    if typeName.contains("Button") || typeName.contains("Item") || sub is UIControl {
                        buttonCandidates.append((r, sub))
                        continue
                    }
                }
                scanButtons(in: sub)
            }
        }
        scanButtons(in: tabBar)

        // 按 minX 去重并排序，筛选出恰好 4 个水平不重叠的槽位
        let sorted = buttonCandidates.sorted { $0.rect.minX < $1.rect.minX }
        var distinct: [(rect: CGRect, view: UIView)] = []
        for cand in sorted {
            if let last = distinct.last, abs(cand.rect.midX - last.rect.midX) < expectedSlotW * 0.45 {
                continue
            }
            distinct.append(cand)
        }

        if distinct.count == count {
            let localFrames = distinct.map { item in
                CGRect(
                    x: item.rect.minX - platterInRoot.minX,
                    y: item.rect.minY - platterInRoot.minY,
                    width: item.rect.width,
                    height: item.rect.height
                )
            }
            var measuredIconCenterY: CGFloat?
            var measuredIconSize: CGSize?
            var measuredLabelCenterY: CGFloat?
            var measuredLabelFontSize: CGFloat?

            func inspectLeaf(_ current: UIView) {
                for sub in current.subviews where !sub.isHidden {
                    if let imgView = sub as? UIImageView, imgView.image != nil, measuredIconCenterY == nil {
                        let r = imgView.convert(imgView.bounds, to: view)
                        if r.width >= 14, r.width <= 38, r.height >= 14, r.height <= 36 {
                            measuredIconCenterY = r.midY - platterInRoot.minY
                            measuredIconSize = r.size
                        }
                    } else if let label = sub as? UILabel, !(label.text ?? "").isEmpty, measuredLabelCenterY == nil {
                        let r = label.convert(label.bounds, to: view)
                        if r.height >= 8, r.height <= 20 {
                            measuredLabelCenterY = r.midY - platterInRoot.minY
                            measuredLabelFontSize = label.font.pointSize
                        }
                    }
                    inspectLeaf(sub)
                }
            }
            for item in distinct {
                inspectLeaf(item.view)
                if measuredIconCenterY != nil && measuredLabelCenterY != nil { break }
            }

            return DockRestingTabBarMetrics(
                platterSize: platterInRoot.size,
                slotFrames: localFrames,
                iconCenterY: measuredIconCenterY ?? (platterInRoot.height * 0.37),
                iconSize: measuredIconSize ?? CGSize(width: 24, height: 24),
                labelCenterY: measuredLabelCenterY ?? (platterInRoot.height * 0.74),
                labelFontSize: measuredLabelFontSize ?? 10
            )
        }

        return .fallback(width: platterInRoot.width, height: platterInRoot.height)
    }

    // MARK: - 菜单装配与选择回调

    private func openOverflowForCurrentTab(tracking: Bool, at point: CGPoint?) {
        cacheRestingBarGeometry()
        guard isSelectedTabAtRootForMenu(), let platter = restingPlatterFrame else { return }
        lastToggleTimestamp = CACurrentMediaTime()

        let activeDockTab = DockTab(rawValue: currentIndex) ?? .battle
        let items = menuItems(for: activeDockTab)
        guard !items.isEmpty else { return }
        let selectedID = currentSelectedItemID(for: activeDockTab)

        overflowMenu.configure(items: items, selectedID: selectedID)
        overflowMenu.open(
            platterFrame: platter,
            slotMetrics: restingSlotMetrics,
            selectedSlot: currentIndex,
            tracking: tracking,
            at: point
        )
    }

    private func menuItems(for tab: DockTab) -> [DockMorphOverflowView.Item] {
        switch tab {
        case .battle:
            return BattleMode.allCases.map { mode in
                DockMorphOverflowView.Item(
                    id: "expandingDock.battleMode.\(mode.rawValue)",
                    title: mode.name,
                    accent: UIColor(mode.color),
                    icon: AnyView(
                        Group {
                            if mode == .all {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.spOrange)
                            } else {
                                mode.icon
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                        }
                    )
                )
            }
        case .coop:
            return CoopRule.allCases.map { rule in
                DockMorphOverflowView.Item(
                    id: "expandingDock.coopRule.\(rule.rawValue)",
                    title: rule.name,
                    accent: UIColor(Color.spGreen),
                    icon: AnyView(
                        Group {
                            if rule == .ALL {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.spGreen)
                            } else {
                                rule.icon
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                        }
                    )
                )
            }
        case .home, .me:
            return []
        }
    }

    private func currentSelectedItemID(for tab: DockTab) -> String {
        switch tab {
        case .battle:
            let modes = BattleListViewModel.shared.filter.modes
            if let first = modes.first, modes.count == 1 {
                return "expandingDock.battleMode.\(first)"
            }
            return "expandingDock.battleMode.\(BattleMode.all.rawValue)"
        case .coop:
            let rules = CoopListViewModel.shared.filter.rules
            if let first = rules.first, rules.count == 1 {
                return "expandingDock.coopRule.\(first)"
            }
            return "expandingDock.coopRule.\(CoopRule.ALL.rawValue)"
        case .home, .me:
            return ""
        }
    }

    private func handlePickedItem(_ id: String) {
        if id.hasPrefix("expandingDock.battleMode.") {
            let raw = String(id.dropFirst("expandingDock.battleMode.".count))
            if let mode = BattleMode(rawValue: raw) {
                Task { @MainActor in
                    await BattleListViewModel.shared.selectModeFromDock(mode)
                }
            }
        } else if id.hasPrefix("expandingDock.coopRule.") {
            let raw = String(id.dropFirst("expandingDock.coopRule.".count))
            if let rule = CoopRule(rawValue: raw) {
                Task { @MainActor in
                    await CoopListViewModel.shared.selectRuleFromDock(rule)
                }
            }
        }
    }
}

// MARK: - 2. 真实 4-Tab 几何测量结构（用于 1:1 对齐过渡排布层）

struct DockRestingTabBarMetrics: Equatable {
    let platterSize: CGSize
    let slotFrames: [CGRect]
    let iconCenterY: CGFloat
    let iconSize: CGSize
    let labelCenterY: CGFloat
    let labelFontSize: CGFloat

    static func fallback(width: CGFloat, height: CGFloat) -> DockRestingTabBarMetrics {
        let insetX: CGFloat = 4
        let insetY: CGFloat = 4
        let count = DockTab.allCases.count
        let slotW = max(1, (width - insetX * 2) / CGFloat(count))
        let slotH = max(1, height - insetY * 2)
        let frames = (0..<count).map { idx in
            CGRect(x: insetX + CGFloat(idx) * slotW, y: insetY, width: slotW, height: slotH)
        }
        return DockRestingTabBarMetrics(
            platterSize: CGSize(width: width, height: height),
            slotFrames: frames,
            iconCenterY: height * 0.37,
            iconSize: CGSize(width: 24, height: 24),
            labelCenterY: height * 0.75,
            labelFontSize: 10
        )
    }
}

// MARK: - 3. 单物体变形玻璃视图 DockMorphOverflowView（480Hz 物理积分 + 实时 4-Tab 过渡层 + 提前交接）

@MainActor
final class DockMorphOverflowView: UIView, UIGestureRecognizerDelegate {
    struct Item: Identifiable {
        let id: String
        let title: String
        let accent: UIColor
        let icon: AnyView
    }

    enum Metrics {
        static let menuRow: CGFloat = 46
        static let menuPadding: CGFloat = 8
        static let morphBlur: CGFloat = 12
        static let morphDuration: TimeInterval = 0.35
        static let morphBounce: CGFloat = 0.28
        static let morphSqueeze: CGFloat = 0.20
        static let squeezeResponse: TimeInterval = 0.50
        static let closeSqueeze: CGFloat = 0.18
        static let squeezeCloseResponse: TimeInterval = 0.25
        static let closeDuration: TimeInterval = 0.25
        static let closeDamping: CGFloat = 0.94
        static let rowRise: CGFloat = 14
        static let rowStagger: TimeInterval = 0.032
        static let rowDelay: TimeInterval = 0.045
        static let rowSpring = Animation.spring(duration: 0.38, bounce: 0.42)
        static let rowFade = Animation.easeOut(duration: 0.16)
        static let indicatorFollow: TimeInterval = 0.05
        static let indicatorFade: TimeInterval = 0.08
        static let menuReach: CGFloat = 20
    }

    var onPick: ((String) -> Void)?
    var onVisibilityChange: ((Bool) -> Void)?
    var onProgressChange: ((CGFloat) -> Void)?
    var onNavigationGuardCheck: (() -> Bool)?

    private(set) var isOpen = false
    private(set) var isMorphing = false
    private(set) var isTracking = false
    var isActive: Bool { isOpen || isMorphing }

    private var items: [Item] = []
    private var selectedID: String = ""

    private var barFrame: CGRect = .zero
    private var slotMetrics: DockRestingTabBarMetrics = .fallback(width: 350, height: 62)
    private var selectedSlot: Int = 0
    private var thickness: CGFloat { max(barFrame.height, 48) }

    private var menuFrame: CGRect {
        let height = max(thickness, CGFloat(items.count) * Metrics.menuRow + Metrics.menuPadding * 2)
        return CGRect(x: barFrame.minX, y: barFrame.maxY - height, width: barFrame.width, height: height)
    }

    /// 单块 `UIGlassEffect(.regular)` 液态玻璃主体（从 `tabBar.frame` 原地长成菜单卡片，再原地缩回）。
    private let glassBar: UIVisualEffectView = {
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        return UIVisualEffectView(effect: effect)
    }()

    private let menuClip = UIView()
    private let menuIndicator = UIView()
    private let indicatorFrost: UIVisualEffectView = {
        let frost = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        frost.isUserInteractionEnabled = false
        frost.contentView.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0, alpha: 0.30) : UIColor(white: 0, alpha: 0.065)
        }
        return frost
    }()

    private let axRowsContainer = UIView()
    private var axRowViews: [UIButton] = []

    private let model = DockMorphMenuModel()
    private lazy var rowsHostView: UIView = {
        let host = UIHostingController(rootView: DockMorphMenuRowsLayer(model: model))
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        return host.view
    }()

    /// 零离屏快照的实时 4-Tab 过渡排布层（替代 `drawHierarchy` 截图，确保收起与展开全程 4 颗按钮同步清晰可见）。
    private lazy var tabsTransitionHostView: UIView = {
        let host = UIHostingController(rootView: DockMorphTabsLayer(model: model))
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        return host.view
    }()

    // CADisplayLink 480Hz 子步弹簧物理状态（静止后立即停表，零空转）
    private var displayLink: CADisplayLink?
    private var trackUntil: CFTimeInterval = 0
    private var glassHeight: CGFloat = 62
    private var glassVelocity: CGFloat = 0
    private var glassTarget: CGFloat = 62
    private var springStiffness: CGFloat = 0
    private var springDamping: CGFloat = 0
    private var lastMorphStep: CFTimeInterval = 0
    private var closingSimulatedTime: CFTimeInterval = 0
    private var pendingPickID: String?

    private var glassSqueeze: CGFloat = 0
    private var glassSqueezeVelocity: CGFloat = 0
    private var squeezeStiffness: CGFloat = 0
    private var squeezeDamping: CGFloat = 0
    private var glassInset: CGFloat = 0

    // 悬停高亮胶囊与手势状态
    private var hoveredRow: Int?
    private var menuOpenPoint: CGPoint?
    private var indicatorRect: CGRect?
    private var indicatorShown: CGFloat = 0
    private var lastIndicatorStep: CFTimeInterval = 0
    private var rubberBandOffsetY: CGFloat = 0
    private let selectionFeedback = UISelectionFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isHidden = true
        isUserInteractionEnabled = false

        glassBar.accessibilityIdentifier = "expandingDock.glassPlatter"
        addSubview(glassBar)

        menuClip.clipsToBounds = true
        menuClip.layer.cornerCurve = .continuous
        menuClip.isUserInteractionEnabled = false
        glassBar.contentView.addSubview(menuClip)

        menuIndicator.isUserInteractionEnabled = false
        menuIndicator.clipsToBounds = true
        menuIndicator.layer.cornerCurve = .continuous
        menuIndicator.alpha = 0
        indicatorFrost.frame = CGRect(x: 0, y: 0, width: 420, height: 120)
        menuIndicator.addSubview(indicatorFrost)
        menuClip.addSubview(menuIndicator)

        menuClip.addSubview(rowsHostView)
        menuClip.addSubview(tabsTransitionHostView)

        axRowsContainer.backgroundColor = .clear
        addSubview(axRowsContainer)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMenuTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleMenuPan(_:)))
        pan.cancelsTouchesInView = true
        pan.delegate = self
        addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 菜单展开期间全屏拦截点击，防止误触底层列表触发详情页 NavigationLink push
        guard isUserInteractionEnabled, !isHidden, isOpen else { return nil }
        return super.hitTest(point, with: event) ?? self
    }

    func configure(items: [Item], selectedID: String) {
        self.items = items
        self.selectedID = selectedID
        rebuildAXRows()

        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            model.rows = items.map { item in
                DockMorphMenuModel.Row(
                    id: item.id,
                    title: item.title,
                    isSelected: item.id == selectedID,
                    icon: item.icon
                )
            }
        }
    }

    func open(
        platterFrame: CGRect,
        slotMetrics: DockRestingTabBarMetrics,
        selectedSlot: Int,
        tracking: Bool,
        at point: CGPoint?
    ) {
        guard !isOpen, !items.isEmpty else { return }
        self.barFrame = platterFrame
        self.slotMetrics = slotMetrics
        self.selectedSlot = selectedSlot

        let radius = thickness / 2
        glassBar.cornerConfiguration = .uniformCorners(radius: .fixed(radius))
        menuClip.layer.cornerRadius = radius

        let reduceMotion = DockMotion.isReduceMotionActive()
        if !isMorphing {
            glassHeight = reduceMotion ? menuFrame.height : thickness
            glassTarget = menuFrame.height
            glassVelocity = 0
            glassSqueeze = 0
            glassSqueezeVelocity = 0
            glassInset = 0
        }
        rubberBandOffsetY = 0
        closingSimulatedTime = 0
        pendingPickID = nil

        isOpen = true
        isTracking = tracking
        menuOpenPoint = tracking ? point : nil
        hoveredRow = items.firstIndex(where: { $0.id == selectedID })
        indicatorRect = nil
        indicatorShown = reduceMotion ? 1 : 0
        lastIndicatorStep = CACurrentMediaTime()

        isHidden = false
        isUserInteractionEnabled = true
        accessibilityViewIsModal = true

        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            model.closing = false
            model.progress = reduceMotion ? 1 : 0
            model.selectedTabIndex = selectedSlot
            model.slotMetrics = slotMetrics
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyGlassGeometry()
        // 强制实时 4-Tab 过渡层在隐藏系统 tabBar 之前就完成首帧排布，杜绝第 0 帧闪烁
        tabsTransitionHostView.layoutIfNeeded()
        CATransaction.commit()

        onVisibilityChange?(true)
        selectionFeedback.selectionChanged()

        if reduceMotion {
            let count = model.rows.count
            var tx2 = Transaction()
            tx2.disablesAnimations = true
            withTransaction(tx2) {
                model.rise = Array(repeating: 0, count: count)
                model.shown = Array(repeating: 1, count: count)
            }
            stepIndicator()
            return
        }

        startOpeningSqueeze()
        startMorph(to: menuFrame.height, response: Metrics.morphDuration, damping: 1 - Metrics.morphBounce)
        riseRows()
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        isTracking = false
        menuOpenPoint = nil
        accessibilityViewIsModal = false
        rubberBandOffsetY = 0

        if DockMotion.isReduceMotionActive() {
            forceCollapseImmediate()
            return
        }

        closingSimulatedTime = 0
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            model.closing = true
        }

        startClosingSqueeze()
        startMorph(to: thickness, response: Metrics.closeDuration, damping: Metrics.closeDamping)
    }

    /// 外部路由触发详情页 push/pop 或 Reduce Motion 收起时，同帧干净收起并恢复真实 `UITabBar`。
    func forceCollapseImmediate() {
        isOpen = false
        isMorphing = false
        isTracking = false
        menuOpenPoint = nil
        accessibilityViewIsModal = false
        rubberBandOffsetY = 0
        closingSimulatedTime = 0
        let deferredPick = pendingPickID
        pendingPickID = nil
        glassHeight = thickness
        glassTarget = thickness
        glassVelocity = 0
        glassSqueeze = 0
        glassSqueezeVelocity = 0
        glassInset = 0
        displayLink?.invalidate()
        displayLink = nil

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        menuIndicator.alpha = 0
        isHidden = true
        isUserInteractionEnabled = false
        onProgressChange?(0)
        onVisibilityChange?(false)
        CATransaction.commit()

        if let deferredPick {
            onPick?(deferredPick)
        }
    }

    // MARK: - 触摸与手势交互（点行 / 上滑悬停高亮 / 下拉橡皮筋收起 / 点击外部收起）

    func updateTracking(at point: CGPoint) {
        guard isOpen else { return }
        if let start = menuOpenPoint {
            guard start.y - point.y > Metrics.menuReach / 2 else { return }
            menuOpenPoint = nil
        }
        let hit = rowIndex(at: point)
        if hit != hoveredRow {
            hoveredRow = hit
            track(for: 0.35)
            if hit != nil {
                selectionFeedback.selectionChanged()
            }
        }
    }

    func endTracking(at point: CGPoint) {
        isTracking = false
        if menuOpenPoint != nil {
            menuOpenPoint = nil
            return
        }
        if let idx = rowIndex(at: point) {
            pickRow(idx)
        } else {
            close()
        }
    }

    func cancelTracking() {
        isTracking = false
        close()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    @objc private func handleMenuTap(_ recognizer: UITapGestureRecognizer) {
        guard isOpen, recognizer.state == .ended else { return }
        let p = recognizer.location(in: self)
        rubberBandOffsetY = 0
        if !menuFrame.contains(p) {
            close()
        }
    }

    @objc private func handleMenuPan(_ recognizer: UIPanGestureRecognizer) {
        guard isOpen else { return }
        let p = recognizer.location(in: self)
        let dy = recognizer.translation(in: self).y
        switch recognizer.state {
        case .began, .changed:
            if dy > 36 && !menuFrame.contains(p) {
                rubberBandOffsetY = (dy - 36) * 0.42
                applyGlassGeometry()
                return
            }
            rubberBandOffsetY = 0
            if let idx = rowIndex(at: p), hoveredRow != idx {
                hoveredRow = idx
                track(for: 0.35)
                selectionFeedback.selectionChanged()
            }
        case .ended:
            if dy > 64 && recognizer.velocity(in: self).y > 120 {
                rubberBandOffsetY = 0
                close()
                return
            }
            rubberBandOffsetY = 0
            if let idx = rowIndex(at: p), menuFrame.insetBy(dx: -12, dy: 0).contains(p) {
                pickRow(idx)
            } else {
                close()
            }
        case .cancelled, .failed:
            rubberBandOffsetY = 0
            applyGlassGeometry()
        default:
            break
        }
    }

    private func pickRow(_ index: Int) {
        guard index >= 0, index < items.count else { return }
        let chosen = items[index]
        selectedID = chosen.id
        hoveredRow = index
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            model.rows = items.map { item in
                DockMorphMenuModel.Row(
                    id: item.id,
                    title: item.title,
                    isSelected: item.id == chosen.id,
                    icon: item.icon
                )
            }
        }
        selectionFeedback.selectionChanged()
        // 将数据库重查与大列表 Diff 延后至收起交接落定瞬间触发，确保 250ms 收起弹簧全程 60/120fps 零掉帧
        pendingPickID = chosen.id
        close()
    }

    private func rowFrameInMenu(_ index: Int) -> CGRect {
        let size = menuFrame.size
        let pad = Metrics.menuPadding
        return CGRect(
            x: pad,
            y: pad + CGFloat(index) * Metrics.menuRow,
            width: size.width - pad * 2,
            height: Metrics.menuRow
        )
    }

    private func rowIndex(at screenPoint: CGPoint) -> Int? {
        let mFrame = menuFrame
        guard mFrame.insetBy(dx: -16, dy: 0).contains(screenPoint) else { return nil }
        let localY = screenPoint.y - mFrame.minY - Metrics.menuPadding
        guard localY >= 0, localY < CGFloat(items.count) * Metrics.menuRow else { return nil }
        return min(max(Int(floor(localY / Metrics.menuRow)), 0), items.count - 1)
    }

    private func rebuildAXRows() {
        axRowViews.forEach { $0.removeFromSuperview() }
        axRowViews = items.enumerated().map { index, item in
            let button = UIButton(type: .custom)
            button.backgroundColor = .clear
            button.accessibilityLabel = item.title
            button.accessibilityIdentifier = item.id
            button.isSelected = (item.id == selectedID)
            button.addAction(UIAction { [weak self] _ in
                self?.pickRow(index)
            }, for: .touchUpInside)
            axRowsContainer.addSubview(button)
            return button
        }
    }

    // MARK: - 逐行自底向上错峰模糊上浮 + 480Hz 弹簧积分与提前交接

    private func riseRows() {
        let count = model.rows.count
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            model.closing = false
            model.rise = Array(repeating: Metrics.rowRise, count: count)
            model.shown = Array(repeating: 0, count: count)
        }
        for order in 0..<count {
            let index = count - 1 - order
            let delay = Metrics.rowDelay + Metrics.rowStagger * Double(order)
            withAnimation(Metrics.rowSpring.delay(delay)) {
                model.rise[index] = 0
            }
            withAnimation(Metrics.rowFade.delay(delay)) {
                model.shown[index] = 1
            }
        }
    }

    private var morphProgress: CGFloat {
        let span = menuFrame.height - thickness
        return span > 0 ? min(max((glassHeight - thickness) / span, 0), 1) : 0
    }

    private func startOpeningSqueeze() {
        let omega = 2 * .pi / CGFloat(Metrics.squeezeResponse)
        squeezeStiffness = omega * omega
        squeezeDamping = 2 * omega
        glassSqueezeVelocity = Metrics.morphSqueeze * omega * exp(1)
    }

    private func startClosingSqueeze() {
        let omega = 2 * .pi / CGFloat(Metrics.squeezeCloseResponse)
        squeezeStiffness = omega * omega
        squeezeDamping = 2 * omega
        let impulse = Metrics.closeSqueeze * omega * exp(1)
        let headroom = max(0, 1 - glassSqueeze / Metrics.closeSqueeze)
        glassSqueezeVelocity = max(glassSqueezeVelocity, impulse * headroom)
    }

    private func startMorph(to height: CGFloat, response: TimeInterval, damping ratio: CGFloat) {
        glassTarget = height
        springStiffness = pow(2 * .pi / CGFloat(response), 2)
        springDamping = 2 * ratio * sqrt(springStiffness)
        if !isMorphing {
            lastMorphStep = CACurrentMediaTime()
        }
        isMorphing = true
        track(for: 0.35)
    }

    private func track(for seconds: CFTimeInterval) {
        trackUntil = max(trackUntil, CACurrentMediaTime() + seconds)
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: DockMorphLinkProxy(self), selector: #selector(DockMorphLinkProxy.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    fileprivate func tick(_ link: CADisplayLink) {
        if let guardCheck = onNavigationGuardCheck, !guardCheck() {
            forceCollapseImmediate()
            return
        }
        if isMorphing {
            stepMorph()
        }
        if isActive {
            stepIndicator()
        }
        if !isMorphing && CACurrentMediaTime() > trackUntil {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    private func stepMorph() {
        let now = CACurrentMediaTime()
        let frameDelta = min(max(now - lastMorphStep, 0), 0.05)
        var remaining = frameDelta
        lastMorphStep = now
        if !isOpen {
            closingSimulatedTime += frameDelta
        }
        let step = 1.0 / 480.0
        while remaining > 0 {
            let dt = CGFloat(min(step, remaining))
            let force = -springStiffness * (glassHeight - glassTarget) - springDamping * glassVelocity
            glassVelocity += force * dt
            glassHeight += glassVelocity * dt
            if squeezeStiffness > 0 {
                let squeezeForce = -squeezeStiffness * glassSqueeze - squeezeDamping * glassSqueezeVelocity
                glassSqueezeVelocity += squeezeForce * dt
                glassSqueeze += glassSqueezeVelocity * dt
            }
            remaining -= Double(dt)
        }

        let currentInset = barFrame.width * max(glassSqueeze, 0) / 2
        let currentWidth = max(44, barFrame.width - currentInset * 2)
        let scaleX = barFrame.width > 0 ? currentWidth / barFrame.width : 1

        let earlyHandoff = DockMorphHandoffPolicy.shouldHandoffToSystemTabBar(
            isOpen: isOpen,
            closingElapsed: closingSimulatedTime,
            currentHeight: glassHeight,
            targetHeight: thickness,
            currentVelocity: glassVelocity,
            scaleX: scaleX
        )

        let heightSettled = abs(glassHeight - glassTarget) < 0.2 && abs(glassVelocity) < 2
        let squeezeSettled = abs(glassSqueeze) < 0.003 && abs(glassSqueezeVelocity) < 0.02

        if earlyHandoff || (heightSettled && squeezeSettled) {
            glassHeight = glassTarget
            glassVelocity = 0
            glassSqueeze = 0
            glassSqueezeVelocity = 0
            if !isOpen {
                // 收起落定瞬间：同一 CATransaction 内同步恢复真实 UITabBar 并隐藏覆盖层，无闪无跳
                finishClosingHandoff()
                return
            }
            applyGlassGeometry()
            isMorphing = false
            return
        }

        if heightSettled {
            glassHeight = glassTarget
            glassVelocity = 0
        }
        if squeezeSettled {
            glassSqueeze = 0
            glassSqueezeVelocity = 0
        }

        applyGlassGeometry()
    }

    private func applyGlassGeometry() {
        let base = barFrame
        glassInset = base.width * max(glassSqueeze, 0) / 2
        let currentWidth = max(44, base.width - glassInset * 2)
        glassBar.bounds = CGRect(x: 0, y: 0, width: currentWidth, height: glassHeight)
        glassBar.center = CGPoint(x: base.midX, y: base.maxY - glassHeight / 2 + rubberBandOffsetY)

        menuClip.frame = glassBar.contentView.bounds
        let fullMenuSize = menuFrame.size
        rowsHostView.frame = CGRect(x: -glassInset, y: 0, width: fullMenuSize.width, height: fullMenuSize.height)

        let scaleX = base.width > 0 ? max(currentWidth / base.width, 0.01) : 1
        tabsTransitionHostView.transform = .identity
        tabsTransitionHostView.bounds = CGRect(origin: .zero, size: CGSize(width: base.width, height: thickness))
        tabsTransitionHostView.center = CGPoint(x: currentWidth / 2, y: glassHeight - thickness / 2)
        if scaleX < 0.9995 {
            tabsTransitionHostView.transform = CGAffineTransform(scaleX: scaleX, y: 1)
        }

        axRowsContainer.frame = CGRect(
            x: base.minX,
            y: base.maxY - glassHeight + rubberBandOffsetY - (fullMenuSize.height - glassHeight),
            width: fullMenuSize.width,
            height: fullMenuSize.height
        )
        for (idx, axRow) in axRowViews.enumerated() {
            axRow.frame = rowFrameInMenu(idx)
        }

        let p = Double(morphProgress)
        if abs(model.progress - p) > 0.0005 {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                model.progress = p
            }
        }
        onProgressChange?(morphProgress)
    }

    private func stepIndicator() {
        let now = CACurrentMediaTime()
        let dt = min(max(now - lastIndicatorStep, 0), 0.05)
        lastIndicatorStep = now

        let activeIndex = isOpen ? (hoveredRow ?? items.firstIndex(where: { $0.id == selectedID })) : nil
        if let idx = activeIndex {
            let targetInFull = rowFrameInMenu(idx)
            let bottomDist = menuFrame.height - targetInFull.minY
            let resolved = CGRect(
                x: targetInFull.minX - glassInset,
                y: glassHeight - bottomDist,
                width: targetInFull.width,
                height: targetInFull.height
            )
            let ease = CGFloat(1 - exp(-dt / Metrics.indicatorFollow))
            if let cur = indicatorRect {
                indicatorRect = CGRect(
                    x: cur.minX + (resolved.minX - cur.minX) * ease,
                    y: cur.minY + (resolved.minY - cur.minY) * ease,
                    width: cur.width + (resolved.width - cur.width) * ease,
                    height: cur.height + (resolved.height - cur.height) * ease
                )
            } else {
                indicatorRect = resolved
            }
        }

        let wantAlpha: CGFloat = (isOpen && activeIndex != nil)
            ? CGFloat(DockMorphCurve.rowsOpacity(Double(morphProgress)))
            : 0
        indicatorShown += (wantAlpha - indicatorShown) * CGFloat(1 - exp(-dt / Metrics.indicatorFade))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let rect = indicatorRect {
            menuIndicator.frame = rect
            menuIndicator.layer.cornerRadius = min(rect.width, rect.height) / 2
        }
        menuIndicator.alpha = min(max(indicatorShown, 0), 1)
        CATransaction.commit()
    }

    private func finishClosingHandoff() {
        isMorphing = false
        closingSimulatedTime = 0
        let deferredPick = pendingPickID
        pendingPickID = nil
        displayLink?.invalidate()
        displayLink = nil

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        menuIndicator.alpha = 0
        isHidden = true
        isUserInteractionEnabled = false
        onProgressChange?(0)
        onVisibilityChange?(false)
        CATransaction.commit()

        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            model.progress = 0
            model.closing = false
        }

        if let deferredPick {
            onPick?(deferredPick)
        }
    }
}

// MARK: - 4. 交叉模糊曲线、极简扁平菜单行层与实时 4-Tab 过渡排布层

private enum DockMorphCurve {
    static func tabsOpacity(_ p: Double) -> Double { 1 - smoothstep(0, 0.6, p) }
    static func rowsOpacity(_ p: Double) -> Double { smoothstep(0.2, 0.9, p) }

    private static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

@MainActor
@Observable
private final class DockMorphMenuModel {
    struct Row: Identifiable {
        let id: String
        let title: String
        let isSelected: Bool
        let icon: AnyView
    }

    var progress: Double = 0
    var rows: [Row] = []
    var rise: [CGFloat] = []
    var shown: [Double] = []
    var closing: Bool = true
    var selectedTabIndex: Int = 0
    var slotMetrics: DockRestingTabBarMetrics = .fallback(width: 350, height: 62)
}

/// 极简扁平模式行（图标 + 模式名 + 右侧选中 ✓），严格对齐视频视觉，无搜索框/标题栏/分组标题/底部入口。
private struct DockMorphMenuRowsLayer: View {
    let model: DockMorphMenuModel

    private func shown(_ index: Int) -> Double {
        index < model.shown.count ? model.shown[index] : 0
    }

    var body: some View {
        let p = model.progress
        VStack(spacing: 0) {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    item.icon
                        .frame(width: 24, height: 24)
                        .padding(.leading, 14)

                    Text(item.title)
                        .font(.system(size: 16, weight: item.isSelected ? .semibold : .regular))
                        .foregroundStyle(Color(uiColor: .label))

                    Spacer(minLength: 8)

                    if item.isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.trailing, 16)
                    }
                }
                .frame(height: DockMorphOverflowView.Metrics.menuRow)
                .blur(radius: DockMorphOverflowView.Metrics.morphBlur * (1 - shown(index)))
                .opacity(shown(index))
                .offset(y: index < model.rise.count ? model.rise[index] : 0)
            }
        }
        .padding(DockMorphOverflowView.Metrics.menuPadding)
        .blur(radius: model.closing ? DockMorphOverflowView.Metrics.morphBlur * (1 - DockMorphCurve.rowsOpacity(p)) : 0)
        .opacity(model.closing ? DockMorphCurve.rowsOpacity(p) : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 零离屏快照的实时 4-Tab 过渡排布层：
/// 在单物体玻璃容器底部与真实 `UITabBar` 4 颗按钮 1:1 对齐绘制全部 4 个模板图标与文字，
/// 彻底消除 `drawHierarchy` 丢弃未选中 3 颗按钮 vibrancy 混合层导致的收起空白 Bug。
private struct DockMorphTabsLayer: View {
    let model: DockMorphMenuModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shown = DockMorphCurve.tabsOpacity(model.progress)
        let metrics = model.slotMetrics
        let tabs = DockTab.allCases

        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    let frame = slotFrame(for: index, in: geo.size, metrics: metrics)
                    let isSelected = (index == model.selectedTabIndex)
                    let foreground = isSelected ? Color.accentColor : Color(uiColor: .label)

                    ZStack {
                        if isSelected {
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
                        }

                        VStack(spacing: 1) {
                            Image(tab.iconName)
                                .renderingMode(.template)
                                .frame(height: 26)
                            Text(tab.localizedTitle)
                                .font(.system(size: max(9.5, min(metrics.labelFontSize, 10.5)), weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(foreground)
                    }
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .blur(radius: DockMorphOverflowView.Metrics.morphBlur * (1 - shown))
        .opacity(shown)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func slotFrame(for index: Int, in size: CGSize, metrics: DockRestingTabBarMetrics) -> CGRect {
        if index < metrics.slotFrames.count,
           metrics.platterSize.width > 1,
           abs(metrics.platterSize.width - size.width) < 4 {
            return metrics.slotFrames[index]
        }
        let insetX: CGFloat = 4
        let insetY: CGFloat = 4
        let count = CGFloat(max(DockTab.allCases.count, 1))
        let slotW = max(1, (size.width - insetX * 2) / count)
        let slotH = max(1, size.height - insetY * 2)
        return CGRect(x: insetX + CGFloat(index) * slotW, y: insetY, width: slotW, height: slotH)
    }
}

// MARK: - 5. 弱引用 DisplayLink 代理与被动原始触摸手势观测器

@MainActor
private final class DockMorphLinkProxy: NSObject {
    weak var owner: DockMorphOverflowView?
    init(_ owner: DockMorphOverflowView) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) { owner?.tick(link) }
}

/// 被动观测原始触摸而不干扰 `UITabBar` 自身手势状态机，支持二次轻触兜底与按住上滑进入菜单。
private final class DockTouchObserverRecognizer: UIGestureRecognizer {
    var onBegan: ((CGPoint) -> Void)?
    var onMoved: ((CGPoint) -> Void)?
    var onEnded: ((CGPoint) -> Void)?
    var onCancelled: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let p = touches.first?.location(in: view) {
            onBegan?(p)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if let p = touches.first?.location(in: view) {
            onMoved?(p)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let p = touches.first?.location(in: view) {
            onEnded?(p)
        }
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        onCancelled?()
        state = .failed
    }
}
