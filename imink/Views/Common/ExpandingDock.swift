import Combine
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// 可展开底部栏（UIKit 原生底导 + 快筛面板）动效常量与辅助工具：
/// - 展开：`UISpringTimingParameters(dampingRatio: 0.74)`（`duration = 0.36s`）+ 水平收腰 `scaleX: 0.80 -> 1.0`；
/// - 收起：`UISpringTimingParameters(dampingRatio: 0.82)`（`duration = 0.28s`，带轻微回弹且底边锁死在 `tabBar` 上沿）；
/// - 逐行错峰上浮：每行独立 `UIViewPropertyAnimator(duration:delay:)`，展开 `delay = index * 0.03s`；
///   收起反序 `0.011s` 阶梯、单行 `0.088s`，总时长 `8 * 0.011 + 0.088 = 0.176s <= 0.18s`；
/// - 开启系统「减弱动态效果」（`Reduce Motion`）时全面降级为纯淡入淡出（`0.18s easeOut`）。
enum DockMotion {
    static let expandDuration: TimeInterval = 0.36
    static let expandDamping: CGFloat = 0.74
    static let collapseDuration: TimeInterval = 0.28
    static let collapseDamping: CGFloat = 0.82
    static let reducedDuration: TimeInterval = 0.18

    /// 水平收腰起始缩放比（`scaleX = 0.80` 起手再经弹簧舒展回 `1.0`）。
    static let openSqueezeScaleX: CGFloat = 0.80
    static let closeSqueezeScaleX: CGFloat = 0.82

    /// 面板逐行错峰参数：展开 `index * 0.03s`；收起 `0.011s` 阶梯 + `0.088s` 单行时长（总时长 `<= 0.18s`）。
    static let rowOpenStaggerStep: TimeInterval = 0.030
    static let rowOpenDuration: TimeInterval = 0.30
    static let rowOpenDamping: CGFloat = 0.78
    static let rowInitialOffsetY: CGFloat = 12
    static let rowCloseStaggerStep: TimeInterval = 0.011
    static let rowCloseItemDuration: TimeInterval = 0.088
    static let maxCloseStaggerIndex: Int = 8

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

/// 搜索匹配与「最近使用」持久化工具（供 UIKit 面板与单元测试直接验证）。
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

/// 四个一级根 Tab 定义（图标取项目 PDF 矢量资源，标题走本地化 key）。
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

    var themeUIColor: UIColor {
        switch self {
        case .home: return UIColor(Color.accentColor)
        case .battle: return UIColor(Color.spOrange)
        case .coop: return UIColor(Color.spGreen)
        case .me: return UIColor(Color.spPurple)
        }
    }
}

// MARK: - SwiftUI Representable 桥接入口

/// 将 UIKit 原生 `UIKitDockTabBarController` 嵌入 `MainView`：
/// - 底栏由系统真实 `UITabBar` + `UITabBarAppearance` 驱动，享受 iOS 26 Liquid Glass 原生透镜与按压反馈；
/// - 筛选面板为自绘 UIKit `UIGlassEffect` / `UIBlurEffect` 容器，底边锚定在 `tabBar` 上沿；
/// - 展开与收起全程绝不隐藏或快照替换 `tabBar`，保证 4 个 Tab 按钮在任意帧均实时可见。
struct ExpandingDockHost: UIViewControllerRepresentable {
    @Binding var tabSelection: Int

    func makeUIViewController(context: Context) -> UIKitDockTabBarController {
        UIKitDockTabBarController(initialSelection: tabSelection) { nextIndex in
            if tabSelection != nextIndex {
                tabSelection = nextIndex
            }
        }
    }

    func updateUIViewController(_ uiViewController: UIKitDockTabBarController, context: Context) {
        uiViewController.syncExternalSelection(tabSelection)
    }
}

// MARK: - 1. Tab 容器 UINavigationController（承托 SwiftUI 页面，保留原 NavigationStack push/sheet 行为）

@MainActor
final class DockTabNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // 各业务根视图（HomePage / BattleListView / CoopListView / MePage）内部自带 NavigationStack，
        // 外层 UINavigationController 隐藏自身导航栏以避免双栏叠加，同时完整保留 UIKit 容器层级与模态弹出链路。
        setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .clear
    }
}

/// 懒加载宿主控制器：仅当某个 Tab 真正被选中进入视图树时才实例化对应 SwiftUI `UIHostingController`，
/// 避免启动首帧同时触发 4 个页面的数据库查询、轮播定时器与网络任务。
@MainActor
private final class LazyTabRootViewController: UIViewController {
    private let makeRootView: () -> AnyView
    private var hostingController: UIHostingController<AnyView>?

    init(makeRootView: @escaping () -> AnyView) {
        self.makeRootView = makeRootView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let host = UIHostingController(rootView: makeRootView())
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        self.hostingController = host
    }
}

/// 被动观测根容器上的原始触摸起止，不拦截任何事件（`cancelsTouchesInView = false`），
/// 用于在 iOS 26 `_UILiquidLensView` 吸收已选中 Tab 原地轻触且未回调 `shouldSelect` 时可靠兜底触发面板开关。
private final class DockTabReTapObserverRecognizer: UIGestureRecognizer {
    var onTouchBegan: ((CGPoint) -> Void)?
    var onTouchEnded: ((CGPoint) -> Void)?
    var onTouchCancelled: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let p = touches.first?.location(in: view) {
            onTouchBegan?(p)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let p = touches.first?.location(in: view) {
            onTouchEnded?(p)
        }
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchCancelled?()
        state = .failed
    }
}

// MARK: - 2. 根底导控制器 UIKitDockTabBarController

@MainActor
final class UIKitDockTabBarController: UITabBarController, UITabBarControllerDelegate, UIGestureRecognizerDelegate {
    private let onSelectionChange: (Int) -> Void
    private var activeIndex: Int
    private var cancellables = Set<AnyCancellable>()

    /// 变暗与轻模糊背景遮罩容器：严格插在 `tabBar` 下方（`insertSubview(..., belowSubview: tabBar)`），
    /// 确保展开/收起全过程中实时 `UITabBar` 永远处于遮罩前方、不被压暗、不丢任何按钮。
    private let backdropContainerView = UIView()
    private let backdropBlurView = UIVisualEffectView(effect: nil)
    private let backdropDimView = UIView()

    /// 锚定于 `tabBar` 上沿的模式快筛面板子控制器。
    private let panelController = DockFilterPanelViewController()

    /// 对战与鲑鱼跑启用筛选时的 6pt 状态圆点（挂载于 `tabBar` 内部，不破坏系统模板图标着色）。
    private let battleFilterDot = UIView()
    private let coopFilterDot = UIView()

    /// 用于去重 `shouldSelect` 与被动触摸观测器，确保真机轻触与 XCUITest 二次点击当前 Tab 100% 稳定触发且绝不双次翻转。
    private var didHandleCurrentTapInDelegate = false
    private var lastPanelToggleTimestamp: CFTimeInterval = 0
    private var touchBeganPoint: CGPoint?
    private var touchBeganOnActiveSlot = false

    init(initialSelection: Int, onSelectionChange: @escaping (Int) -> Void) {
        self.activeIndex = min(max(initialSelection, 0), DockTab.allCases.count - 1)
        self.onSelectionChange = onSelectionChange
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        view.backgroundColor = .clear

        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .never
        }

        setupTabNavigationControllers()
        configureSystemTabBarAppearance()
        setupBackdropAndPanelHierarchy()
        setupTabBarPassiveReTapRecognizer()
        setupFilterDots()
        bindViewModels()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if backdropContainerView.frame != view.bounds {
            backdropContainerView.frame = view.bounds
        }
        if panelController.view.frame != view.bounds {
            panelController.view.frame = view.bounds
        }

        // 仅在层级顺序不满足「业务页面(index 0) < 变暗遮罩 < 系统浮动底栏 < 顶沿面板透传层」时调整一次，
        // 严禁在 viewDidLayoutSubviews 中无条件交换 subviews 引发主线程死循环布局！
        ensureOverlaySubviewOrder()

        let platterRect = measureTabBarPlatterRectInView()
        let barTopFromBottom = max(0, view.bounds.height - platterRect.minY)
        if barTopFromBottom > 40, abs(FloatingBarInsets.measuredCustomDockTop - barTopFromBottom) > 0.5 {
            FloatingBarInsets.measuredCustomDockTop = barTopFromBottom
        }
        DockVisibilityStore.shared.collapsedHitRect = platterRect
        panelController.updateAnchorTabBarRect(platterRect)
        layoutFilterDots(in: platterRect)
    }

    private func ensureOverlaySubviewOrder() {
        // UITabBarController.view 的第 0 层是承载各 Tab 页面的 UITransitionView，
        // 其上方依次为 iOS 26 实际绘制液态玻璃胶囊的 _UITabBarContainerView 与 UITabBar。
        // 必须将 backdropContainerView 严格锁在 transitionView 正上方（transIdx + 1），
        // 才能确保 _UITabBarContainerView 与 UITabBar 全程位于变暗模糊遮罩前方，4 颗按钮永远清晰可见！
        guard let transitionView = view.subviews.first(where: {
            $0 !== backdropContainerView && $0 !== panelController.view && $0 !== tabBar
                && String(describing: type(of: $0)).contains("Transition")
        }) ?? view.subviews.first(where: {
            $0 !== backdropContainerView && $0 !== panelController.view
        }) else {
            return
        }
        if let backdropIdx = view.subviews.firstIndex(of: backdropContainerView),
           let transIdx = view.subviews.firstIndex(of: transitionView),
           backdropIdx != transIdx + 1 {
            view.insertSubview(backdropContainerView, aboveSubview: transitionView)
        }
        for dot in [battleFilterDot, coopFilterDot] where dot.superview === view {
            if let dotIdx = view.subviews.firstIndex(of: dot),
               let panelIdx = view.subviews.firstIndex(of: panelController.view),
               dotIdx != panelIdx - 1 && dotIdx != panelIdx - 2 {
                view.insertSubview(dot, belowSubview: panelController.view)
            }
        }
        if view.subviews.last !== panelController.view {
            view.bringSubviewToFront(panelController.view)
        }
    }

    func syncExternalSelection(_ externalIndex: Int) {
        let clamped = min(max(externalIndex, 0), DockTab.allCases.count - 1)
        guard clamped != activeIndex || selectedIndex != clamped else { return }
        activeIndex = clamped
        if selectedIndex != clamped {
            selectedIndex = clamped
        }
        if panelController.isExpanded {
            panelController.collapse(reason: .tabSwitch)
        }
    }

    // MARK: - 4 个 Tab 的 UINavigationController + UIHostingController 组装

    private func setupTabNavigationControllers() {
        let mainVM = MainViewModel.shared
        let battleVM = BattleListViewModel.shared
        let coopVM = CoopListViewModel.shared
        let bgTaskMgr = BackgroundTaskManager.shared
        let notifMgr = NotificationManager.shared
        let subMgr = ScheduleSubscriptionManager.shared

        let controllers: [UINavigationController] = DockTab.allCases.map { dockTab in
            let lazyRoot = LazyTabRootViewController {
                let pageView: AnyView
                switch dockTab {
                case .home:
                    pageView = AnyView(HomePage(viewModel: HomeViewModel()))
                case .battle:
                    pageView = AnyView(BattleListView())
                case .coop:
                    pageView = AnyView(CoopListView())
                case .me:
                    pageView = AnyView(MePage())
                }

                return AnyView(
                    pageView
                        .environmentObject(mainVM)
                        .environmentObject(battleVM)
                        .environmentObject(coopVM)
                        .environmentObject(bgTaskMgr)
                        .environmentObject(notifMgr)
                        .environmentObject(subMgr)
                        .appGameTypography()
                        .appLineHeight()
                )
            }

            let nav = DockTabNavigationController(rootViewController: lazyRoot)
            let icon = UIImage(named: dockTab.iconName)?.withRenderingMode(.alwaysTemplate)
            let item = UITabBarItem(title: dockTab.localizedTitle, image: icon, selectedImage: icon)
            item.tag = dockTab.rawValue
            item.accessibilityLabel = dockTab.localizedTitle
            item.accessibilityIdentifier = "expandingDock.tab.\(dockTab.rawValue)"
            nav.tabBarItem = item
            return nav
        }

        setViewControllers(controllers, animated: false)
        selectedIndex = activeIndex
    }

    private func configureSystemTabBarAppearance() {
        let accent = UIColor(Color.accentColor)
        tabBar.tintColor = accent
        tabBar.unselectedItemTintColor = UIColor.secondaryLabel
        tabBar.isTranslucent = true

        let appearance = tabBar.standardAppearance.copy()
        if UIAccessibility.isReduceTransparencyEnabled {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .secondarySystemBackground
        } else {
            appearance.configureWithDefaultBackground()
        }

        let tabFont = Font.gameUIFont(size: 11, weight: .semibold)
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: tabFont,
            .foregroundColor: UIColor.secondaryLabel,
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: tabFont,
            .foregroundColor: accent,
        ]
        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            layout.normal.titleTextAttributes = normalAttrs
            layout.selected.titleTextAttributes = selectedAttrs
            layout.selected.iconColor = accent
        }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    private func setupBackdropAndPanelHierarchy() {
        backdropContainerView.frame = view.bounds
        backdropContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropContainerView.isHidden = true
        backdropContainerView.accessibilityElementsHidden = true

        backdropBlurView.frame = backdropContainerView.bounds
        backdropBlurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropBlurView.alpha = 0.52
        backdropBlurView.isUserInteractionEnabled = false
        backdropContainerView.addSubview(backdropBlurView)

        backdropDimView.frame = backdropContainerView.bounds
        backdropDimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropDimView.alpha = 0
        backdropDimView.isUserInteractionEnabled = false
        updateBackdropDimColor()
        backdropContainerView.addSubview(backdropDimView)

        let backdropTap = UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap))
        backdropContainerView.addGestureRecognizer(backdropTap)
        if let firstSub = view.subviews.first {
            view.insertSubview(backdropContainerView, aboveSubview: firstSub)
        } else {
            view.insertSubview(backdropContainerView, belowSubview: tabBar)
        }

        addChild(panelController)
        panelController.view.frame = view.bounds
        panelController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(panelController.view)
        panelController.didMove(toParent: self)

        panelController.backdropBlurView = backdropBlurView
        panelController.backdropDimView = backdropDimView
        panelController.backdropContainerView = backdropContainerView
        panelController.onRequestTabSwitch = { [weak self] targetTab in
            guard let self else { return }
            self.activeIndex = targetTab.rawValue
            self.selectedIndex = targetTab.rawValue
            self.onSelectionChange(targetTab.rawValue)
        }

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.updateBackdropDimColor()
            self.configureSystemTabBarAppearance()
        }
    }

    private func updateBackdropDimColor() {
        let alpha: CGFloat = traitCollection.userInterfaceStyle == .dark ? 0.26 : 0.12
        backdropDimView.backgroundColor = UIColor.black.withAlphaComponent(alpha)
    }

    private func setupFilterDots() {
        for (dot, color) in [(battleFilterDot, UIColor(Color.spOrange)), (coopFilterDot, UIColor(Color.spGreen))] {
            dot.backgroundColor = color
            dot.layer.cornerRadius = 3
            dot.isUserInteractionEnabled = false
            dot.isHidden = true
            view.insertSubview(dot, belowSubview: panelController.view)
        }
    }

    private func layoutFilterDots(in platterRectInView: CGRect) {
        guard platterRectInView.width > 80 else { return }
        let slotWidth = platterRectInView.width / CGFloat(DockTab.allCases.count)

        let battleSlotMidX = platterRectInView.minX + slotWidth * 1.5
        battleFilterDot.frame = CGRect(x: battleSlotMidX + 10, y: platterRectInView.minY + 8, width: 6, height: 6)
        battleFilterDot.isHidden = !BattleListViewModel.shared.hasAnyActiveFilter

        let coopSlotMidX = platterRectInView.minX + slotWidth * 2.5
        coopFilterDot.frame = CGRect(x: coopSlotMidX + 10, y: platterRectInView.minY + 8, width: 6, height: 6)
        coopFilterDot.isHidden = !CoopListViewModel.shared.hasAnyActiveFilter
    }

    private func bindViewModels() {
        BattleListViewModel.shared.$filter
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.layoutFilterDots(in: self.measureTabBarPlatterRectInView())
                if self.panelController.isExpanded {
                    self.panelController.refreshContentIfExpanded()
                }
            }
            .store(in: &cancellables)

        CoopListViewModel.shared.$filter
            .combineLatest(CoopListViewModel.shared.$isShowingShiftCards)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.layoutFilterDots(in: self.measureTabBarPlatterRectInView())
                if self.panelController.isExpanded {
                    self.panelController.refreshContentIfExpanded()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.configureSystemTabBarAppearance()
                self?.panelController.applyMaterialAppearance()
            }
            .store(in: &cancellables)
    }

    // MARK: - 测量系统 UITabBar / 浮动胶囊容器实际几何区域

    private func measureTabBarPlatterRectInView() -> CGRect {
        var bestEffectPlatter: CGRect?
        var narrowestPlatter: CGRect?

        func scanSubtree(_ current: UIView) {
            for sub in current.subviews where !sub.isHidden && sub.alpha > 0.05 {
                if sub === backdropContainerView || sub === panelController.view
                    || sub === battleFilterDot || sub === coopFilterDot {
                    continue
                }
                let typeName = String(describing: type(of: sub))
                if typeName.contains("Transition") { continue }

                let candidate = sub.convert(sub.bounds, to: view)
                let isCapsuleSized = candidate.minY >= view.bounds.height - 120
                    && candidate.width >= view.bounds.width * 0.68
                    && candidate.width <= view.bounds.width - 26
                    && candidate.height >= 48
                    && candidate.height <= 70

                if isCapsuleSized {
                    if sub is UIVisualEffectView || typeName.contains("Platter") || typeName.contains("Glass") {
                        bestEffectPlatter = candidate
                    }
                    if let existing = narrowestPlatter {
                        if candidate.width <= existing.width + 0.5 && candidate.height <= existing.height + 0.5 {
                            narrowestPlatter = candidate
                        }
                    } else {
                        narrowestPlatter = candidate
                    }
                }
                scanSubtree(sub)
            }
        }

        scanSubtree(view)
        if let bestEffectPlatter {
            return bestEffectPlatter
        }
        if let narrowestPlatter {
            return narrowestPlatter
        }
        let horizontalInset: CGFloat = 20.33
        let height: CGFloat = 62.67
        let bottomPad: CGFloat = max(view.safeAreaInsets.bottom - 12.67, 21.33)
        return CGRect(
            x: horizontalInset,
            y: max(0, view.bounds.height - bottomPad - height),
            width: max(240, view.bounds.width - horizontalInset * 2),
            height: height
        )
    }

    // MARK: - UITabBarControllerDelegate & 二次点击当前 Tab 展开/收起

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        guard let controllers = tabBarController.viewControllers,
              let tappedIndex = controllers.firstIndex(of: viewController) else {
            return true
        }
        didHandleCurrentTapInDelegate = true

        if tappedIndex == activeIndex {
            triggerPanelToggleWithCooldown()
            return false
        }

        if panelController.isExpanded {
            panelController.collapse(reason: .tabSwitch)
        }
        activeIndex = tappedIndex
        onSelectionChange(tappedIndex)
        return true
    }

    private func setupTabBarPassiveReTapRecognizer() {
        let observer = DockTabReTapObserverRecognizer()
        observer.cancelsTouchesInView = false
        observer.delaysTouchesBegan = false
        observer.delaysTouchesEnded = false
        observer.delegate = self
        observer.onTouchBegan = { [weak self] point in
            self?.handleObserverTouchBegan(at: point)
        }
        observer.onTouchEnded = { [weak self] point in
            self?.handleObserverTouchEnded(at: point)
        }
        observer.onTouchCancelled = { [weak self] in
            self?.touchBeganPoint = nil
            self?.touchBeganOnActiveSlot = false
        }
        view.addGestureRecognizer(observer)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private func handleObserverTouchBegan(at point: CGPoint) {
        didHandleCurrentTapInDelegate = false
        // 同步系统栏真实选中项
        if selectedIndex >= 0, selectedIndex < DockTab.allCases.count {
            activeIndex = selectedIndex
        }
        if panelController.isExpanded, panelController.currentPanelFrameInHost.contains(point) {
            touchBeganPoint = nil
            touchBeganOnActiveSlot = false
            return
        }
        let platter = measureTabBarPlatterRectInView()
        guard platter.insetBy(dx: -10, dy: -16).contains(point) else {
            touchBeganPoint = nil
            touchBeganOnActiveSlot = false
            return
        }
        let slotWidth = platter.width / CGFloat(max(DockTab.allCases.count, 1))
        let slot = min(
            max(Int((point.x - platter.minX) / max(slotWidth, 1)), 0),
            DockTab.allCases.count - 1
        )
        touchBeganPoint = point
        touchBeganOnActiveSlot = (slot == activeIndex)
    }

    private func handleObserverTouchEnded(at point: CGPoint) {
        let wasActiveSlot = touchBeganOnActiveSlot
        let start = touchBeganPoint
        touchBeganPoint = nil
        touchBeganOnActiveSlot = false

        guard wasActiveSlot, let start, hypot(point.x - start.x, point.y - start.y) < 22 else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.didHandleCurrentTapInDelegate else { return }
            self.triggerPanelToggleWithCooldown()
        }
    }

    private func triggerPanelToggleWithCooldown() {
        let now = CACurrentMediaTime()
        guard now - lastPanelToggleTimestamp > 0.20 else { return }
        lastPanelToggleTimestamp = now
        togglePanelForCurrentTab()
    }

    private func togglePanelForCurrentTab() {
        let currentTab = DockTab(rawValue: activeIndex) ?? .home
        if panelController.isExpanded {
            panelController.collapse(reason: .reTapTab)
        } else {
            Haptics.generateIfEnabled(.light)
            panelController.expand(for: currentTab)
        }
    }

    @objc private func handleBackdropTap() {
        panelController.collapse(reason: .backdropTap)
    }
}

// MARK: - 3. 并集轮廓几何计算、马鞍反向圆角 Mask 与面板透传宿主视图

/// 以纯矢量 `CAShapeLayer` 阶梯羽化构成的遮罩视图，专供 `UIVisualEffectView.mask` 转发至内部 backdrop/tint 子层：
/// - 主体层 `100%` 不透明压住胶囊顶沿与圆肩 `2.0pt` 边线；
/// - 底部两道 `0.67pt` 微阶梯（`+2.67pt @ 0.55`、`+3.33pt @ 0.22`）实现亚像素光学过渡，零阴影光栅化开销、零嵌套 mask 风险。
private final class DockSaddleMaskView: UIView {
    override class var layerClass: AnyClass { CAShapeLayer.self }

    private let midFeatherLayer = CAShapeLayer()
    private let outerFeatherLayer = CAShapeLayer()

    private var coreShapeLayer: CAShapeLayer {
        // swiftlint:disable:next force_cast
        layer as! CAShapeLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        coreShapeLayer.fillColor = UIColor.black.cgColor
        midFeatherLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        outerFeatherLayer.fillColor = UIColor.black.withAlphaComponent(0.22).cgColor
        layer.addSublayer(midFeatherLayer)
        layer.addSublayer(outerFeatherLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updatePaths(corePath: CGPath, midFeatherPath: CGPath?, outerFeatherPath: CGPath?) {
        coreShapeLayer.path = corePath
        midFeatherLayer.frame = bounds
        midFeatherLayer.path = midFeatherPath
        outerFeatherLayer.frame = bounds
        outerFeatherLayer.path = outerFeatherPath
    }
}

/// 动画期专用的轻量 `CADisplayLink` 弱引用代理（静止即销毁，零常驻开销）。
@MainActor
private final class DockMorphDisplayLinkTarget: NSObject {
    weak var owner: DockFilterPanelViewController?
    init(_ owner: DockFilterPanelViewController) { self.owner = owner }
    @objc func step(_ link: CADisplayLink) { owner?.handleMorphDisplayLinkTick() }
}

/// 面板与底部系统胶囊的「无缝反向圆角并集」几何构造器：
/// - 当面板贴合底栏时，面板两侧外墙笔直延伸至胶囊赤道略下 `capsuleMidY + rimOverlap`（与圆弧切向偏离仅 `0.11pt`），
///   再用两段半径严格等于 `R` 的反向内凹圆弧（`addArc(..., clockwise: false)`）同轴覆盖系统胶囊左右顶肩与顶部高光边；
/// - 外轮廓描边采用精确圆弧上半拱（`U` 形双层细边：外暗边 + 内高光边），在胶囊赤道处平滑汇入系统胶囊原生边线，
///   既无中间横缝，也绝不在胶囊下半圆产生超椭圆外鼓重影。
private enum DockUnionGeometry {
    /// 压住系统胶囊顶边及左右圆肩高光/暗边的核心不透明重叠量（2.0pt = 6px@3x，羽化带止于 3.33pt，严守在选中滑块 +4.67pt 之上）。
    static let capsuleRimOverlap: CGFloat = 2.0

    /// 让 `UIVisualEffectView` 底部超出遮罩裁切线，从而把系统玻璃自带的底边高光环彻底裁掉。
    static let glassBottomBleed: CGFloat = 48.0

    /// 构造精确圆弧顶角 + 垂直侧墙的外包络路径（避免 `UIBezierPath(roundedRect:)` 超椭圆在圆角处与圆形胶囊错位）。
    static func makeExactStadiumEnvelopePath(
        width: CGFloat,
        height: CGFloat,
        radius: CGFloat,
        inset: CGFloat = 0
    ) -> UIBezierPath {
        let w = max(width, radius * 2 + 2)
        let h = max(height, radius * 2)
        let r = max(2, min(radius, min(w, h) / 2) - inset)
        let minX = inset
        let maxX = w - inset
        let minY = inset
        let maxY = h - inset

        let path = UIBezierPath()
        path.move(to: CGPoint(x: minX, y: minY + r))
        path.addArc(
            withCenter: CGPoint(x: minX + r, y: minY + r),
            radius: r,
            startAngle: .pi,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: maxX - r, y: minY))
        path.addArc(
            withCenter: CGPoint(x: maxX - r, y: minY + r),
            radius: r,
            startAngle: 1.5 * .pi,
            endAngle: 2.0 * .pi,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY - r))
        path.addArc(
            withCenter: CGPoint(x: maxX - r, y: maxY - r),
            radius: r,
            startAngle: 0,
            endAngle: 0.5 * .pi,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: minX + r, y: maxY))
        path.addArc(
            withCenter: CGPoint(x: minX + r, y: maxY - r),
            radius: r,
            startAngle: 0.5 * .pi,
            endAngle: .pi,
            clockwise: true
        )
        path.close()
        return path
    }

    /// 构造面板局部坐标系下的反向圆角马鞍遮罩路径（`width = W`，顶部至胶囊顶边距离为 `bodyHeight`）。
    static func makePanelMaskPath(
        width: CGFloat,
        bodyHeight: CGFloat,
        capsuleRadius: CGFloat,
        isFloatingAboveKeyboard: Bool,
        extraOverlap: CGFloat = 0
    ) -> UIBezierPath {
        let w = max(width, capsuleRadius * 2 + 2)
        if isFloatingAboveKeyboard {
            let h = max(bodyHeight, capsuleRadius * 2)
            return makeExactStadiumEnvelopePath(
                width: w,
                height: h,
                radius: min(DockConfig.cornerRadius, h / 2)
            )
        }

        let r = min(capsuleRadius, w / 2 - 1)
        let overlap = min(capsuleRimOverlap + extraOverlap, r * 0.25)
        let clampedBodyH = max(0, bodyHeight)
        let shoulderCenterY = clampedBodyH + r + overlap
        let topRadius = min(r, max(12, (clampedBodyH + r) * 0.5))

        let path = UIBezierPath()
        // 1. 左上外圆角
        path.move(to: CGPoint(x: 0, y: topRadius))
        path.addArc(
            withCenter: CGPoint(x: topRadius, y: topRadius),
            radius: topRadius,
            startAngle: .pi,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        // 2. 顶边 + 右上外圆角
        path.addLine(to: CGPoint(x: w - topRadius, y: 0))
        path.addArc(
            withCenter: CGPoint(x: w - topRadius, y: topRadius),
            radius: topRadius,
            startAngle: 1.5 * .pi,
            endAngle: 2.0 * .pi,
            clockwise: true
        )
        // 3. 右侧外墙直达胶囊赤道切点 (w, shoulderCenterY)
        path.addLine(to: CGPoint(x: w, y: shoulderCenterY))
        // 4. 右下同半径反向内凹圆弧（完整盖住系统胶囊右肩高光暗边，无月牙漏边）
        path.addArc(
            withCenter: CGPoint(x: w - r, y: shoulderCenterY),
            radius: r,
            startAngle: 0,
            endAngle: 1.5 * .pi,
            clockwise: false
        )
        // 5. 横跨胶囊顶部平直交界线（零缝贴死并盖住胶囊顶边高光条）
        path.addLine(to: CGPoint(x: r, y: clampedBodyH + overlap))
        // 6. 左下同半径反向内凹圆弧（完整盖住系统胶囊左肩高光暗边，C1 垂直切向落回左侧外墙）
        path.addArc(
            withCenter: CGPoint(x: r, y: shoulderCenterY),
            radius: r,
            startAngle: 1.5 * .pi,
            endAngle: .pi,
            clockwise: false
        )
        // 7. 闭合回到左上角起点
        path.close()
        return path
    }

    /// 构造并集外轮廓描边路径：
    /// - 贴合态只描上半拱（左赤道 -> 左墙 -> 顶边 -> 右墙 -> 右赤道），下半圆交由系统胶囊原生玻璃边线无缝接管；
    /// - 键盘悬空态描完整闭合跑道框。
    static func makeUnionPerimeterPath(
        width: CGFloat,
        bodyHeight: CGFloat,
        capsuleRadius: CGFloat,
        inset: CGFloat,
        isFloatingAboveKeyboard: Bool
    ) -> UIBezierPath {
        let w = max(width, capsuleRadius * 2 + 2)
        if isFloatingAboveKeyboard {
            let h = max(bodyHeight, capsuleRadius * 2)
            return makeExactStadiumEnvelopePath(
                width: w,
                height: h,
                radius: min(DockConfig.cornerRadius, h / 2),
                inset: inset
            )
        }

        let clampedBodyH = max(0, bodyHeight)
        let r = max(2, min(capsuleRadius, w / 2 - 1) - inset)
        let topR = max(2, min(capsuleRadius, max(12, (clampedBodyH + capsuleRadius) * 0.5)) - inset)
        let minX = inset
        let maxX = w - inset
        let minY = inset
        let equatorEndY = clampedBodyH + capsuleRadius + 2

        let path = UIBezierPath()
        path.move(to: CGPoint(x: minX, y: equatorEndY))
        path.addLine(to: CGPoint(x: minX, y: minY + topR))
        path.addArc(
            withCenter: CGPoint(x: minX + topR, y: minY + topR),
            radius: topR,
            startAngle: .pi,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: maxX - topR, y: minY))
        path.addArc(
            withCenter: CGPoint(x: maxX - topR, y: minY + topR),
            radius: topR,
            startAngle: 1.5 * .pi,
            endAngle: 2.0 * .pi,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: maxX, y: max(minY + r, equatorEndY)))
        return path
    }
}

private final class DockPanelPassThroughView: UIView {
    var activePanelFrameProvider: (() -> CGRect?)?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, let panelRect = activePanelFrameProvider?() else {
            return nil
        }
        guard panelRect.insetBy(dx: -4, dy: 0).contains(point) else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

// MARK: - 4. 模式快筛面板控制器 DockFilterPanelViewController（胶囊同源并集生长版）

@MainActor
final class DockFilterPanelViewController: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate {
    enum CollapseReason {
        case reTapTab
        case backdropTap
        case swipeDown
        case pickedItem
        case navigationAction
        case tabSwitch
    }

    struct PanelItemModel {
        let id: String
        let recentKey: String?
        let title: String
        let keywords: [String]
        let isSelected: Bool
        let isNavigation: Bool
        let badgeCount: Int
        let tintColor: UIColor
        let iconImage: UIImage?
        let rendersAsTemplate: Bool
        let action: () -> Void
    }

    struct PanelSectionModel {
        let id: String
        let header: String?
        let items: [PanelItemModel]
    }

    weak var backdropContainerView: UIView?
    weak var backdropBlurView: UIVisualEffectView?
    weak var backdropDimView: UIView?
    var onRequestTabSwitch: ((DockTab) -> Void)?

    private(set) var isExpanded = false
    var currentPanelFrameInHost: CGRect { activeInteractivePanelRect }
    private var activeTab: DockTab = .battle
    private var anchorTabBarRect: CGRect = .zero
    private var searchQuery: String = ""
    private var keyboardOverlapHeight: CGFloat = 0
    private var dragTranslationY: CGFloat = 0

    // 供 UIViewPropertyAnimator 驱动真实弹簧插值（bounds.height = 生长高度 0..Hp，transform.a = 水平收腰比例）的隐形物理探针
    private let springDriverView = UIView()
    private var morphDisplayLink: CADisplayLink?
    private var currentRenderedBodyHeight: CGFloat = 0
    private var currentRenderedScaleX: CGFloat = 1.0
    private var targetExpandedBodyHeight: CGFloat = 320
    private var activeInteractivePanelRect: CGRect = .zero

    // 仅向上方散射的环境阴影层（严格裁掉 tabBar 区域，绝不向实时胶囊投射暗影造成接缝色差）
    private let upperAmbientShadowView = UIView()
    private let upperShadowClipMask = CAShapeLayer()

    // 并集玻璃宿主、马鞍反向圆角遮罩、接缝光学补偿层、内容裁切容器与唯一连续外轮廓描边层
    private let platterHostView = UIView()
    private let platterGlassView = UIVisualEffectView(effect: nil)
    private let platterTintCalibrator = UIView()
    private let glassSaddleMaskView = DockSaddleMaskView()
    private let contentClipContainer = UIView()
    private let contentSaddleMaskLayer = CAShapeLayer()
    private let contentInnerCanvas = UIView()
    private let unionPerimeterStrokeView = UIView()
    private let unionOuterHairlineLayer = CAShapeLayer()
    private let unionPerimeterStrokeLayer = CAShapeLayer()
    private let unionStrokeFadeMask = CAGradientLayer()

    // 标题把手区 + 36pt 搜索框 + 滚动列表区 + 底部固定入口
    private let grabberPill = UIView()
    private let headerContainer = UIView()
    private let headerBadgeLabel = UILabel()
    private let headerBadgeBg = UIView()
    private let headerTitleLabel = UILabel()
    private let headerStatusLabel = UILabel()

    private let searchBoxGlassView = UIVisualEffectView(effect: nil)
    private let searchIconView = UIImageView()
    private let searchTextField = UITextField()
    private let searchClearButton = UIButton(type: .custom)

    private let rowsScrollView = UIScrollView()
    private let rowsStackView = UIStackView()

    private let footerSeparator = UIView()
    private let footerHostView = UIView()

    // 可打断物理弹簧动画器与逐行错峰动画器集合
    private var panelAnimator: UIViewPropertyAnimator?
    private var rowAnimators: [UIViewPropertyAnimator] = []
    private var animatedSlotsBottomUp: [UIView] = []
    private var cancellables = Set<AnyCancellable>()

    override func loadView() {
        let passThrough = DockPanelPassThroughView()
        passThrough.backgroundColor = .clear
        passThrough.isOpaque = false
        passThrough.activePanelFrameProvider = { [weak self] in
            guard let self, self.isExpanded else { return nil }
            return self.activeInteractivePanelRect
        }
        self.view = passThrough
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isHidden = true
        setupPlatterChrome()
        setupHeaderAndSearchViews()
        setupRowsScrollAndFooter()
        setupGestures()
        setupKeyboardObservers()
        applyMaterialAppearance()

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.applyMaterialAppearance()
            if self.isExpanded {
                self.rebuildSections(animateHeight: false)
            }
        }
    }

    func updateAnchorTabBarRect(_ rect: CGRect) {
        anchorTabBarRect = rect
        if isExpanded && panelAnimator?.isRunning != true {
            targetExpandedBodyHeight = measureDesiredPanelHeight()
            currentRenderedBodyHeight = targetExpandedBodyHeight
            currentRenderedScaleX = 1.0
            renderUnionFrame(bodyHeight: currentRenderedBodyHeight, scaleX: currentRenderedScaleX)
        }
    }

    func refreshContentIfExpanded() {
        guard isExpanded else { return }
        rebuildSections(animateHeight: true)
    }

    // MARK: - 视图搭建（100% UIKit，并集马鞍遮罩 + 单一外轮廓描边）

    private func setupPlatterChrome() {
        springDriverView.isHidden = true
        springDriverView.isUserInteractionEnabled = false
        view.addSubview(springDriverView)

        upperAmbientShadowView.isUserInteractionEnabled = false
        upperAmbientShadowView.backgroundColor = .clear
        upperAmbientShadowView.layer.shadowColor = UIColor.black.cgColor
        upperAmbientShadowView.layer.shadowOffset = CGSize(width: 0, height: -2)
        upperAmbientShadowView.layer.shadowRadius = 16
        upperShadowClipMask.fillRule = .evenOdd
        upperShadowClipMask.fillColor = UIColor.black.cgColor
        upperAmbientShadowView.layer.mask = upperShadowClipMask
        view.addSubview(upperAmbientShadowView)

        platterHostView.backgroundColor = .clear
        view.addSubview(platterHostView)

        platterGlassView.clipsToBounds = true
        platterHostView.addSubview(platterGlassView)

        platterTintCalibrator.isUserInteractionEnabled = false
        platterGlassView.contentView.addSubview(platterTintCalibrator)

        contentClipContainer.backgroundColor = .clear
        contentClipContainer.layer.mask = contentSaddleMaskLayer
        contentSaddleMaskLayer.fillColor = UIColor.black.cgColor
        platterHostView.addSubview(contentClipContainer)

        contentInnerCanvas.backgroundColor = .clear
        contentClipContainer.addSubview(contentInnerCanvas)

        unionPerimeterStrokeView.isUserInteractionEnabled = false
        unionPerimeterStrokeView.backgroundColor = .clear
        unionOuterHairlineLayer.fillColor = nil
        unionOuterHairlineLayer.lineWidth = 0.67
        unionPerimeterStrokeView.layer.addSublayer(unionOuterHairlineLayer)
        unionPerimeterStrokeLayer.fillColor = nil
        unionPerimeterStrokeLayer.lineWidth = 0.85
        unionPerimeterStrokeView.layer.addSublayer(unionPerimeterStrokeLayer)
        unionStrokeFadeMask.colors = [
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor,
        ]
        unionStrokeFadeMask.startPoint = CGPoint(x: 0.5, y: 0.0)
        unionStrokeFadeMask.endPoint = CGPoint(x: 0.5, y: 1.0)
        unionPerimeterStrokeView.layer.mask = unionStrokeFadeMask
        view.addSubview(unionPerimeterStrokeView)
    }

    private func setupHeaderAndSearchViews() {
        let content = contentInnerCanvas

        grabberPill.backgroundColor = UIColor.label.withAlphaComponent(0.22)
        grabberPill.layer.cornerRadius = 2
        headerContainer.addSubview(grabberPill)

        headerBadgeBg.layer.cornerRadius = 9
        headerBadgeBg.layer.cornerCurve = .continuous
        headerContainer.addSubview(headerBadgeBg)

        headerBadgeLabel.font = Font.gameUIFont(size: 11, weight: .semibold)
        headerContainer.addSubview(headerBadgeLabel)

        headerTitleLabel.font = Font.gameUIFont(size: 15, weight: .semibold)
        headerTitleLabel.textColor = UIColor(Color.appLabel)
        headerContainer.addSubview(headerTitleLabel)

        headerStatusLabel.font = Font.gameUIFont(size: 11)
        headerStatusLabel.textColor = .secondaryLabel
        headerStatusLabel.textAlignment = .right
        headerContainer.addSubview(headerStatusLabel)

        content.addSubview(headerContainer)

        // 36pt 高玻璃底搜索框（圆角 12）
        searchBoxGlassView.clipsToBounds = true
        searchBoxGlassView.layer.cornerRadius = 12
        searchBoxGlassView.layer.cornerCurve = .continuous
        searchBoxGlassView.layer.borderWidth = 0.8
        content.addSubview(searchBoxGlassView)

        let searchContent = searchBoxGlassView.contentView
        searchIconView.image = UIImage(
            systemName: "magnifyingglass",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )
        searchIconView.tintColor = .secondaryLabel
        searchIconView.contentMode = .scaleAspectFit
        searchContent.addSubview(searchIconView)

        searchTextField.delegate = self
        searchTextField.font = Font.gameUIFont(size: 13)
        searchTextField.textColor = UIColor(Color.appLabel)
        searchTextField.tintColor = UIColor(Color.accentColor)
        searchTextField.returnKeyType = .search
        searchTextField.autocorrectionType = .no
        searchTextField.autocapitalizationType = .none
        searchTextField.clearButtonMode = .never
        searchTextField.accessibilityIdentifier = "expandingDock.searchField"
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "搜索模式或规则",
            attributes: [
                .font: Font.gameUIFont(size: 12),
                .foregroundColor: UIColor.secondaryLabel,
            ]
        )
        searchTextField.addTarget(self, action: #selector(handleSearchEditingChanged), for: .editingChanged)
        searchContent.addSubview(searchTextField)

        searchClearButton.setImage(
            UIImage(
                systemName: "xmark.circle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            ),
            for: .normal
        )
        searchClearButton.tintColor = .secondaryLabel
        searchClearButton.isHidden = true
        searchClearButton.accessibilityLabel = "清除搜索词"
        searchClearButton.accessibilityIdentifier = "expandingDock.searchClearButton"
        searchClearButton.addTarget(self, action: #selector(handleClearSearchTapped), for: .touchUpInside)
        searchContent.addSubview(searchClearButton)
    }

    private func setupRowsScrollAndFooter() {
        let content = contentInnerCanvas

        rowsScrollView.showsVerticalScrollIndicator = false
        rowsScrollView.showsHorizontalScrollIndicator = false
        rowsScrollView.delaysContentTouches = false
        rowsScrollView.canCancelContentTouches = true
        rowsScrollView.keyboardDismissMode = .interactive
        content.addSubview(rowsScrollView)

        rowsStackView.axis = .vertical
        rowsStackView.alignment = .fill
        rowsStackView.spacing = 2
        rowsScrollView.addSubview(rowsStackView)

        footerSeparator.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
        content.addSubview(footerSeparator)
        content.addSubview(footerHostView)
    }

    func applyMaterialAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let reduceTrans = UIAccessibility.isReduceTransparencyEnabled

        if reduceTrans {
            platterGlassView.effect = nil
            platterGlassView.backgroundColor = .secondarySystemBackground
            platterTintCalibrator.backgroundColor = .clear
            unionOuterHairlineLayer.strokeColor = UIColor.clear.cgColor
            unionPerimeterStrokeLayer.strokeColor = UIColor.separator.withAlphaComponent(0.55).cgColor
            searchBoxGlassView.effect = nil
            searchBoxGlassView.backgroundColor = .tertiarySystemFill
        } else {
            platterGlassView.backgroundColor = .clear
            // 采用 UIBlurEffect(.systemThickMaterial) + 像素级标定中性光学补偿层：
            // 实测浅色模式下 .systemThickMaterial 底色约 RGB(246,246,246)，叠加 alpha=0.038 中性暗调补偿后
            // 精确落点 RGB(236.6,236.4,236.6)，与下方实时 UITabBar 液态玻璃胶囊内部 RGB(236.0~237.5) 实现 ΔRGB < 1.5 对齐！
            platterGlassView.effect = UIBlurEffect(style: .systemThickMaterial)
            platterTintCalibrator.backgroundColor = isDark
                ? UIColor(white: 0.06, alpha: 0.12)
                : UIColor(white: 0.0, alpha: 0.038)

            unionOuterHairlineLayer.strokeColor = UIColor.black
                .withAlphaComponent(isDark ? 0.34 : 0.16)
                .cgColor
            unionPerimeterStrokeLayer.strokeColor = UIColor.white
                .withAlphaComponent(isDark ? 0.20 : 0.56)
                .cgColor

            searchBoxGlassView.effect = UIBlurEffect(style: .systemUltraThinMaterial)
            searchBoxGlassView.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(isDark ? 0.32 : 0.45)
        }

        searchBoxGlassView.layer.borderColor = UIColor.white
            .withAlphaComponent(isDark ? 0.20 : 0.50)
            .cgColor
        upperAmbientShadowView.layer.shadowOpacity = isDark ? 0.28 : 0.10
    }

    // MARK: - 展开 / 收起（生长起点 = 系统胶囊矩形本身，从 bodyHeight = 0 连续向上长出并集轮廓）

    func expand(for tab: DockTab) {
        activeTab = tab
        searchQuery = ""
        searchTextField.text = ""
        searchClearButton.isHidden = true
        dragTranslationY = 0

        let interruptedMidFlight = panelAnimator?.state == .active
        stopActiveAnimatorsPreservingCurrentState()

        isExpanded = true
        DockVisibilityStore.shared.expand()

        view.isHidden = false
        view.isUserInteractionEnabled = true
        platterHostView.accessibilityElementsHidden = false
        platterHostView.accessibilityViewIsModal = true

        backdropContainerView?.isHidden = false
        backdropContainerView?.isUserInteractionEnabled = true

        rebuildSections(animateHeight: false)
        let targetHeight = measureDesiredPanelHeight()
        targetExpandedBodyHeight = targetHeight
        layoutInternalContentCanvas(bodyHeight: targetHeight)

        let reduceMotion = DockMotion.isReduceMotionActive()
        if reduceMotion {
            currentRenderedBodyHeight = targetHeight
            currentRenderedScaleX = 1.0
            renderUnionFrame(bodyHeight: targetHeight, scaleX: 1.0)
            platterHostView.alpha = 0
            unionPerimeterStrokeView.alpha = 0
            animatedSlotsBottomUp.forEach {
                $0.alpha = 1
                $0.transform = .identity
            }
            let anim = UIViewPropertyAnimator(duration: DockMotion.reducedDuration, curve: .easeOut)
            anim.addAnimations {
                self.platterHostView.alpha = 1
                self.unionPerimeterStrokeView.alpha = 1
                self.backdropDimView?.alpha = 1
                if !UIAccessibility.isReduceTransparencyEnabled {
                    self.backdropBlurView?.effect = UIBlurEffect(style: .systemUltraThinMaterial)
                }
            }
            anim.startAnimation()
            panelAnimator = anim
            return
        }

        // 生长起点严格等于底导胶囊自身（bodyHeight = 0，即第一帧与胶囊矩形完全重合），随后边收腰边向上生长
        let startBodyH = interruptedMidFlight ? currentRenderedBodyHeight : 0
        let startScaleX = interruptedMidFlight ? currentRenderedScaleX : DockMotion.openSqueezeScaleX

        platterHostView.alpha = 1
        unionPerimeterStrokeView.alpha = 1
        springDriverView.transform = .identity
        springDriverView.bounds = CGRect(x: 0, y: 0, width: 100, height: startBodyH)
        springDriverView.transform = CGAffineTransform(scaleX: startScaleX, y: 1.0)
        renderUnionFrame(bodyHeight: startBodyH, scaleX: startScaleX)

        startMorphDisplayLink()

        let spring = UISpringTimingParameters(
            dampingRatio: DockMotion.expandDamping,
            initialVelocity: CGVector(dx: 0.35, dy: 0.55)
        )
        let animator = UIViewPropertyAnimator(duration: DockMotion.expandDuration, timingParameters: spring)
        animator.isInterruptible = true
        animator.isUserInteractionEnabled = true
        animator.addAnimations {
            self.springDriverView.bounds = CGRect(x: 0, y: 0, width: 100, height: targetHeight)
            self.springDriverView.transform = .identity
            self.backdropDimView?.alpha = 1
            if !UIAccessibility.isReduceTransparencyEnabled {
                self.backdropBlurView?.effect = UIBlurEffect(style: .systemUltraThinMaterial)
            }
        }
        animator.addCompletion { [weak self] pos in
            guard let self else { return }
            if pos == .end && self.isExpanded {
                self.stopMorphDisplayLink()
                self.currentRenderedBodyHeight = self.targetExpandedBodyHeight
                self.currentRenderedScaleX = 1.0
                self.renderUnionFrame(bodyHeight: self.targetExpandedBodyHeight, scaleX: 1.0)
            }
        }
        animator.startAnimation()
        panelAnimator = animator

        // 逐行内容从胶囊后方升起（同时受 contentSaddleMaskLayer 裁切在并集轮廓内，绝不溢出成两张皮）
        for (index, slotView) in animatedSlotsBottomUp.enumerated() {
            slotView.alpha = 0
            slotView.transform = CGAffineTransform(translationX: 0, y: DockMotion.rowInitialOffsetY + 14)
            let rowTiming = UISpringTimingParameters(dampingRatio: DockMotion.rowOpenDamping)
            let rowAnim = UIViewPropertyAnimator(duration: DockMotion.rowOpenDuration, timingParameters: rowTiming)
            rowAnim.addAnimations {
                slotView.alpha = 1
                slotView.transform = .identity
            }
            rowAnim.startAnimation(afterDelay: Double(index) * DockMotion.rowOpenStaggerStep)
            rowAnimators.append(rowAnim)
        }
    }

    func collapse(reason: CollapseReason, completion: (() -> Void)? = nil) {
        guard isExpanded else {
            completion?()
            return
        }

        let hadKeyboard = searchTextField.isFirstResponder || keyboardOverlapHeight > 10
        if reason != .pickedItem {
            Haptics.generateIfEnabled(.light)
        }

        // 规格要求：键盘弹出时若点遮罩或下滑收起，必须先收键盘、再收面板
        if hadKeyboard && (reason == .backdropTap || reason == .swipeDown || reason == .reTapTab) {
            searchTextField.resignFirstResponder()
            resetInteractiveDragIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.performCollapseAnimation(reason: reason, completion: completion)
            }
            return
        }

        if hadKeyboard {
            searchTextField.resignFirstResponder()
        }
        performCollapseAnimation(reason: reason, completion: completion)
    }

    private func performCollapseAnimation(reason: CollapseReason, completion: (() -> Void)?) {
        guard isExpanded else {
            completion?()
            return
        }
        isExpanded = false
        dragTranslationY = 0
        DockVisibilityStore.shared.collapse()

        // 立即释放模态无障碍拦截，同时保持并集玻璃与内部行完整反向缩回胶囊
        view.isUserInteractionEnabled = false
        backdropContainerView?.isUserInteractionEnabled = false
        platterHostView.accessibilityViewIsModal = false
        platterHostView.accessibilityElementsHidden = true

        stopActiveAnimatorsPreservingCurrentState()

        let reduceMotion = DockMotion.isReduceMotionActive()
        if reduceMotion {
            let anim = UIViewPropertyAnimator(duration: DockMotion.reducedDuration, curve: .easeOut)
            anim.addAnimations {
                self.platterHostView.alpha = 0
                self.unionPerimeterStrokeView.alpha = 0
                self.backdropDimView?.alpha = 0
                self.backdropBlurView?.effect = nil
            }
            anim.addCompletion { [weak self] pos in
                guard let self, pos == .end, !self.isExpanded else { return }
                self.finishCollapsedHiddenState()
                completion?()
            }
            anim.startAnimation()
            panelAnimator = anim
            return
        }

        // 收起逐行错峰：自顶向下反序 0.011s 阶梯 + 0.088s 单行时长（8 * 0.011 + 0.088 = 0.176s <= 0.18s）
        let topDownSlots = Array(animatedSlotsBottomUp.reversed())
        for (idx, slotView) in topDownSlots.enumerated() {
            let clampedStep = min(idx, DockMotion.maxCloseStaggerIndex)
            let rowAnim = UIViewPropertyAnimator(duration: DockMotion.rowCloseItemDuration, curve: .easeIn)
            rowAnim.addAnimations {
                slotView.alpha = 0
                slotView.transform = CGAffineTransform(translationX: 0, y: 12)
            }
            rowAnim.startAnimation(afterDelay: Double(clampedStep) * DockMotion.rowCloseStaggerStep)
            rowAnimators.append(rowAnim)
        }

        // 从当前高度连续缩回胶囊矩形本身（targetBodyHeight = 0），实时底栏 4 颗按钮全程在下方零闪烁可见
        springDriverView.transform = .identity
        springDriverView.bounds = CGRect(x: 0, y: 0, width: 100, height: currentRenderedBodyHeight)
        springDriverView.transform = CGAffineTransform(scaleX: currentRenderedScaleX, y: 1.0)
        startMorphDisplayLink()

        let damping: CGFloat = (reason == .pickedItem) ? 0.84 : DockMotion.collapseDamping
        let spring = UISpringTimingParameters(
            dampingRatio: max(damping, 0.84),
            initialVelocity: CGVector(dx: 0, dy: -0.25)
        )
        let animator = UIViewPropertyAnimator(duration: DockMotion.collapseDuration, timingParameters: spring)
        animator.isInterruptible = true
        animator.addAnimations {
            self.springDriverView.bounds = CGRect(x: 0, y: 0, width: 100, height: 0)
            self.springDriverView.transform = CGAffineTransform(scaleX: 0.96, y: 1.0)
            self.backdropDimView?.alpha = 0
            self.backdropBlurView?.effect = nil
        }
        animator.addCompletion { [weak self] position in
            guard let self, position == .end, !self.isExpanded else { return }
            self.finishCollapsedHiddenState()
            completion?()
        }
        animator.startAnimation()
        panelAnimator = animator
    }

    private func finishCollapsedHiddenState() {
        stopMorphDisplayLink()
        searchQuery = ""
        searchTextField.text = ""
        searchClearButton.isHidden = true
        currentRenderedBodyHeight = 0
        currentRenderedScaleX = 1.0
        platterHostView.alpha = 1
        unionPerimeterStrokeView.alpha = 1
        view.isHidden = true
        backdropContainerView?.isHidden = true
    }

    private func stopActiveAnimatorsPreservingCurrentState() {
        if let presentation = springDriverView.layer.presentation() {
            currentRenderedBodyHeight = max(0, presentation.bounds.height)
            currentRenderedScaleX = max(0.75, min(1.08, presentation.affineTransform().a))
        }
        stopMorphDisplayLink()

        if let active = panelAnimator, active.state == .active {
            active.stopAnimation(true)
        }
        panelAnimator = nil

        for anim in rowAnimators where anim.state == .active {
            anim.stopAnimation(true)
        }
        rowAnimators.removeAll()
    }

    private func startMorphDisplayLink() {
        guard morphDisplayLink == nil else { return }
        let link = CADisplayLink(
            target: DockMorphDisplayLinkTarget(self),
            selector: #selector(DockMorphDisplayLinkTarget.step(_:))
        )
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        morphDisplayLink = link
    }

    private func stopMorphDisplayLink() {
        morphDisplayLink?.invalidate()
        morphDisplayLink = nil
    }

    fileprivate func handleMorphDisplayLinkTick() {
        guard let pres = springDriverView.layer.presentation() else { return }
        let h = max(0, pres.bounds.height)
        let sx = max(0.75, min(1.08, pres.affineTransform().a))
        currentRenderedBodyHeight = h
        currentRenderedScaleX = sx
        renderUnionFrame(bodyHeight: h, scaleX: sx)

        // 收起尾段当生长高度回到 < 2pt（完全收回胶囊轮廓内）时淡出描边，无缝交棒给原生胶囊
        if !isExpanded {
            let fade = min(1, max(0, h / 18.0))
            platterHostView.alpha = fade
            unionPerimeterStrokeView.alpha = fade
        }
    }

    // MARK: - 并集轮廓实时几何渲染与键盘避让

    private var resolvedCapsuleRect: CGRect {
        if anchorTabBarRect.width > 200 && anchorTabBarRect.height >= 44 {
            return anchorTabBarRect
        }
        let hostW = view.bounds.width > 0 ? view.bounds.width : 402
        let hostH = view.bounds.height > 0 ? view.bounds.height : 874
        return CGRect(x: 20.33, y: hostH - 84, width: hostW - 40.66, height: 62.67)
    }

    private var resolvedPanelWidth: CGFloat {
        resolvedCapsuleRect.width
    }

    private var isFloatingAboveKeyboard: Bool {
        keyboardOverlapHeight > 10
    }

    private var resolvedSeamAnchorY: CGFloat {
        let hostH = view.bounds.height > 0 ? view.bounds.height : 874
        let capsuleTopY = resolvedCapsuleRect.minY
        if isFloatingAboveKeyboard {
            let keyboardClearY = hostH - keyboardOverlapHeight - 8
            return min(capsuleTopY, keyboardClearY)
        }
        // 底边零缝贴死在系统 tabBar 胶囊顶边！
        return capsuleTopY
    }

    private func measureDesiredPanelHeight() -> CGFloat {
        let pad = DockConfig.panelPadding
        let headerH: CGFloat = 42
        let searchH: CGFloat = 36
        let spacingAfterHeader: CGFloat = 6
        let spacingAfterSearch: CGFloat = 6
        let hasFooter = !footerHostView.isHidden
        let footerBlockH: CGFloat = hasFooter ? (8 + DockConfig.panelRowHeight) : 0

        let stackFitting = rowsStackView.systemLayoutSizeFitting(
            CGSize(width: resolvedPanelWidth - pad * 2, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let naturalRowsH = max(stackFitting.height, DockConfig.panelRowHeight)

        let safeTop = max(view.safeAreaInsets.top, 54)
        let maxTotalPanelH = max(196, min(464, resolvedSeamAnchorY - safeTop - 10))
        let fixedChromeH = pad + headerH + spacingAfterHeader + searchH + spacingAfterSearch + footerBlockH + pad
        let maxViewportH = max(76, maxTotalPanelH - fixedChromeH)

        let viewportH = min(naturalRowsH, maxViewportH)
        rowsScrollView.isScrollEnabled = naturalRowsH > viewportH + 1

        return fixedChromeH + viewportH
    }

    /// 排版固定高度的面板内部画布（在开合形变期间随 `contentInnerCanvas.frame.origin.y` 从胶囊后升起）。
    private func layoutInternalContentCanvas(bodyHeight: CGFloat) {
        let width = resolvedPanelWidth
        let pad = DockConfig.panelPadding
        contentInnerCanvas.bounds = CGRect(x: 0, y: 0, width: width, height: bodyHeight)

        let innerW = width - pad * 2
        var cursorY: CGFloat = pad + 2

        headerContainer.frame = CGRect(x: pad, y: cursorY, width: innerW, height: 42)
        grabberPill.frame = CGRect(x: (innerW - 34) / 2, y: 2, width: 34, height: 4)

        headerBadgeLabel.sizeToFit()
        let badgeW = headerBadgeLabel.bounds.width + 14
        let badgeH: CGFloat = 20
        headerBadgeBg.frame = CGRect(x: 6, y: 14, width: badgeW, height: badgeH)
        headerBadgeLabel.frame = CGRect(x: 13, y: 14, width: headerBadgeLabel.bounds.width, height: badgeH)

        headerStatusLabel.sizeToFit()
        let statusW = min(headerStatusLabel.bounds.width, 110)
        headerStatusLabel.frame = CGRect(x: innerW - 6 - statusW, y: 14, width: statusW, height: 20)

        let titleX = headerBadgeBg.frame.maxX + 8
        let titleMaxW = max(60, headerStatusLabel.frame.minX - titleX - 6)
        headerTitleLabel.frame = CGRect(x: titleX, y: 13, width: titleMaxW, height: 22)

        cursorY += 42 + 6

        // 36pt 搜索框
        searchBoxGlassView.frame = CGRect(x: pad, y: cursorY, width: innerW, height: 36)
        searchIconView.frame = CGRect(x: 10, y: 10, width: 16, height: 16)
        let clearW: CGFloat = searchClearButton.isHidden ? 0 : 28
        searchClearButton.frame = CGRect(x: innerW - 32, y: 4, width: 28, height: 28)
        let fieldX: CGFloat = 32
        searchTextField.frame = CGRect(
            x: fieldX,
            y: 0,
            width: max(60, innerW - fieldX - clearW - 8),
            height: 36
        )

        cursorY += 36 + 6

        let hasFooter = !footerHostView.isHidden
        let footerReserved: CGFloat = hasFooter ? (8 + DockConfig.panelRowHeight) : 0
        let scrollH = max(40, bodyHeight - cursorY - footerReserved - pad)

        rowsScrollView.frame = CGRect(x: pad, y: cursorY, width: innerW, height: scrollH)
        let stackSize = rowsStackView.systemLayoutSizeFitting(
            CGSize(width: innerW, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        rowsStackView.frame = CGRect(x: 0, y: 0, width: innerW, height: stackSize.height)
        rowsScrollView.contentSize = CGSize(width: innerW, height: stackSize.height)

        if hasFooter {
            let sepY = rowsScrollView.frame.maxY + 4
            footerSeparator.frame = CGRect(x: pad + 6, y: sepY, width: innerW - 12, height: 0.6)
            footerHostView.frame = CGRect(
                x: pad,
                y: sepY + 4,
                width: innerW,
                height: DockConfig.panelRowHeight
            )
            footerHostView.subviews.first?.frame = footerHostView.bounds
        }
    }

    /// 实时将当前弹簧高度 `bodyHeight` 与收腰比例 `scaleX` 渲染为「反向圆角马鞍并集遮罩 + 唯一连续外轮廓描边」。
    private func renderUnionFrame(bodyHeight: CGFloat, scaleX: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let capsule = resolvedCapsuleRect
        let capsuleR = capsule.height / 2
        let floating = isFloatingAboveKeyboard
        let baseW = capsule.width
        let currentW = max(capsuleR * 2 + 4, baseW * scaleX)
        let seamY = resolvedSeamAnchorY + (floating ? dragTranslationY : max(0, dragTranslationY))
        let clampedBodyH = max(0, bodyHeight - max(0, dragTranslationY))
        let topY = seamY - clampedBodyH
        let minX = capsule.midX - currentW / 2

        let skirtDepth: CGFloat = floating ? 0 : (capsuleR + DockUnionGeometry.capsuleRimOverlap + 2.0)
        let hostHeight = clampedBodyH + skirtDepth
        let hostFrame = CGRect(x: minX, y: topY, width: currentW, height: max(1, hostHeight))
        platterHostView.frame = hostFrame

        // 仅保留胶囊上方的可点击热区，保证下半截实时 UITabBar 4 颗按钮 100% 原生接收触摸
        activeInteractivePanelRect = CGRect(x: minX, y: topY, width: currentW, height: clampedBodyH)

        // 让玻璃视图向下额外出血 48pt，再用马鞍遮罩裁切，确保底部不会出现任何残余边缘线
        let glassFrame = CGRect(
            x: 0,
            y: 0,
            width: currentW,
            height: hostHeight + DockUnionGeometry.glassBottomBleed
        )
        platterGlassView.frame = glassFrame
        platterTintCalibrator.frame = platterGlassView.bounds

        let saddlePath = DockUnionGeometry.makePanelMaskPath(
            width: currentW,
            bodyHeight: clampedBodyH,
            capsuleRadius: capsuleR,
            isFloatingAboveKeyboard: floating
        )
        let midFeather = floating ? nil : DockUnionGeometry.makePanelMaskPath(
            width: currentW,
            bodyHeight: clampedBodyH,
            capsuleRadius: capsuleR,
            isFloatingAboveKeyboard: false,
            extraOverlap: 0.67
        ).cgPath
        let outerFeather = floating ? nil : DockUnionGeometry.makePanelMaskPath(
            width: currentW,
            bodyHeight: clampedBodyH,
            capsuleRadius: capsuleR,
            isFloatingAboveKeyboard: false,
            extraOverlap: 1.33
        ).cgPath
        glassSaddleMaskView.frame = glassFrame
        glassSaddleMaskView.updatePaths(
            corePath: saddlePath.cgPath,
            midFeatherPath: midFeather,
            outerFeatherPath: outerFeather
        )
        // 按 UIVisualEffectView 官方规范重置 mask 属性，使内部 backdrop 子层即时同步最新马鞍几何
        platterGlassView.mask = glassSaddleMaskView

        contentClipContainer.frame = CGRect(x: 0, y: 0, width: currentW, height: max(1, hostHeight))
        contentSaddleMaskLayer.frame = contentClipContainer.bounds
        contentSaddleMaskLayer.path = saddlePath.cgPath

        // 内部内容画布底边对齐接缝线：展开时随生长高度从胶囊背后同步升起，收起时同步缩回胶囊背后
        let fullContentH = max(targetExpandedBodyHeight, clampedBodyH)
        let canvasOffsetX = (currentW - baseW) / 2
        let canvasOffsetY = clampedBodyH - fullContentH
        contentInnerCanvas.frame = CGRect(x: canvasOffsetX, y: canvasOffsetY, width: baseW, height: fullContentH)

        // 唯一一条连续外轮廓双层细描边：在胶囊赤道处经渐变平滑交棒给系统胶囊原生边线，零横缝、零底角重影
        let strokeBoxH = floating ? max(1, clampedBodyH) : max(1, clampedBodyH + capsuleR + 3)
        unionPerimeterStrokeView.frame = CGRect(x: minX, y: topY, width: currentW, height: strokeBoxH)
        unionOuterHairlineLayer.frame = unionPerimeterStrokeView.bounds
        unionOuterHairlineLayer.path = DockUnionGeometry.makeUnionPerimeterPath(
            width: currentW,
            bodyHeight: clampedBodyH,
            capsuleRadius: capsuleR,
            inset: 0.33,
            isFloatingAboveKeyboard: floating
        ).cgPath
        unionPerimeterStrokeLayer.frame = unionPerimeterStrokeView.bounds
        unionPerimeterStrokeLayer.path = DockUnionGeometry.makeUnionPerimeterPath(
            width: currentW,
            bodyHeight: clampedBodyH,
            capsuleRadius: capsuleR,
            inset: 1.0,
            isFloatingAboveKeyboard: floating
        ).cgPath
        unionStrokeFadeMask.frame = unionPerimeterStrokeView.bounds
        if floating {
            unionStrokeFadeMask.locations = [0.0, 1.0, 1.0]
        } else {
            let fadeStart = max(0.0, min(0.96, Double((strokeBoxH - 9.0) / max(strokeBoxH, 1.0))))
            unionStrokeFadeMask.locations = [0.0, NSNumber(value: fadeStart), 1.0]
        }

        // 环境柔和阴影：采用 even-odd 挖空实时胶囊内部，既不压暗实时底栏，也不在胶囊左右背景留水平裁切线
        upperAmbientShadowView.frame = view.bounds
        let shadowEnvelope = DockUnionGeometry.makeExactStadiumEnvelopePath(
            width: currentW,
            height: max(1, clampedBodyH + capsuleR),
            radius: capsuleR
        )
        shadowEnvelope.apply(CGAffineTransform(translationX: minX, y: topY))
        upperAmbientShadowView.layer.shadowPath = shadowEnvelope.cgPath

        let shadowCutout = UIBezierPath(rect: view.bounds)
        let capsuleHole = DockUnionGeometry.makeExactStadiumEnvelopePath(
            width: capsule.width,
            height: capsule.height,
            radius: capsuleR
        )
        capsuleHole.apply(CGAffineTransform(translationX: capsule.minX, y: capsule.minY))
        shadowCutout.append(capsuleHole)
        upperShadowClipMask.frame = view.bounds
        upperShadowClipMask.path = shadowCutout.cgPath

        CATransaction.commit()
    }

    // MARK: - 搜索输入与键盘通知

    @objc private func handleSearchEditingChanged() {
        searchQuery = searchTextField.text ?? ""
        searchClearButton.isHidden = searchQuery.isEmpty
        rebuildSections(animateHeight: true)
    }

    @objc private func handleClearSearchTapped() {
        Haptics.generateIfEnabled(.light)
        searchQuery = ""
        searchTextField.text = ""
        searchClearButton.isHidden = true
        rebuildSections(animateHeight: true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self else { return }
                guard let endFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
                    return
                }
                let windowHeight = self.view.window?.bounds.height ?? self.view.bounds.height
                let overlap = max(0, windowHeight - endFrame.minY)
                self.animateKeyboardAdjustment(to: overlap, userInfo: note.userInfo)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                self?.animateKeyboardAdjustment(to: 0, userInfo: note.userInfo)
            }
            .store(in: &cancellables)
    }

    private func animateKeyboardAdjustment(to overlap: CGFloat, userInfo: [AnyHashable: Any]?) {
        guard abs(keyboardOverlapHeight - overlap) > 0.5 else { return }
        keyboardOverlapHeight = overlap
        guard isExpanded else { return }

        let duration = (userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.28
        let rawCurve = (userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
        let options = UIView.AnimationOptions(rawValue: rawCurve << 16)

        let desiredH = measureDesiredPanelHeight()
        targetExpandedBodyHeight = desiredH
        currentRenderedBodyHeight = desiredH
        layoutInternalContentCanvas(bodyHeight: desiredH)

        UIView.animate(withDuration: max(duration, 0.18), delay: 0, options: [options, .beginFromCurrentState]) {
            self.renderUnionFrame(bodyHeight: desiredH, scaleX: self.currentRenderedScaleX)
        }
    }

    // MARK: - 下滑交互手势（跟手压缩并集高度 + 抬手判定收起或回弹）

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanelPan(_:)))
        pan.delegate = self
        platterHostView.addGestureRecognizer(pan)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: platterHostView)
        guard abs(velocity.y) > abs(velocity.x) * 1.15 else { return false }
        let touchInScroll = pan.location(in: rowsScrollView)
        if rowsScrollView.bounds.contains(touchInScroll) && rowsScrollView.isScrollEnabled {
            return rowsScrollView.contentOffset.y <= 0.5 && velocity.y > 0
        }
        return true
    }

    @objc private func handlePanelPan(_ recognizer: UIPanGestureRecognizer) {
        guard isExpanded else { return }
        let dy = recognizer.translation(in: view).y
        let vy = recognizer.velocity(in: view).y

        switch recognizer.state {
        case .began, .changed:
            dragTranslationY = dy > 0 ? dy * 0.66 : dy * 0.12
            let progress = min(1, max(0, dy / 170))
            DockVisibilityStore.shared.dragDismissProgress = progress
            backdropDimView?.alpha = 1 - progress * 0.85
            renderUnionFrame(bodyHeight: targetExpandedBodyHeight, scaleX: 1.0)

        case .ended:
            if dy > 48 || vy > 320 {
                let effectiveRemainingH = max(0, targetExpandedBodyHeight - max(0, dragTranslationY))
                currentRenderedBodyHeight = effectiveRemainingH
                dragTranslationY = 0
                collapse(reason: .swipeDown)
            } else {
                resetInteractiveDragIfNeeded()
            }

        case .cancelled, .failed:
            resetInteractiveDragIfNeeded()

        default:
            break
        }
    }

    private func resetInteractiveDragIfNeeded() {
        let startH = max(0, targetExpandedBodyHeight - max(0, dragTranslationY))
        dragTranslationY = 0
        DockVisibilityStore.shared.dragDismissProgress = 0
        let duration = DockMotion.isReduceMotionActive() ? DockMotion.reducedDuration : 0.26

        springDriverView.transform = .identity
        springDriverView.bounds = CGRect(x: 0, y: 0, width: 100, height: startH)
        startMorphDisplayLink()

        let anim = UIViewPropertyAnimator(
            duration: duration,
            timingParameters: UISpringTimingParameters(dampingRatio: 0.84)
        )
        anim.addAnimations {
            self.backdropDimView?.alpha = 1
            self.springDriverView.bounds = CGRect(x: 0, y: 0, width: 100, height: self.targetExpandedBodyHeight)
        }
        anim.addCompletion { [weak self] _ in
            guard let self, self.isExpanded else { return }
            self.stopMorphDisplayLink()
            self.currentRenderedBodyHeight = self.targetExpandedBodyHeight
            self.renderUnionFrame(bodyHeight: self.targetExpandedBodyHeight, scaleX: 1.0)
        }
        anim.startAnimation()
        panelAnimator = anim
    }

    // MARK: - 数据源构建与 UI 行刷新（搜索 + 最近使用 + 分组 + 单选无 ›）

    private var isSearching: Bool {
        !DockSearchSupport.normalize(searchQuery).isEmpty
    }

    private func rebuildSections(animateHeight: Bool) {
        configureHeaderContent()

        rowsStackView.arrangedSubviews.forEach { sub in
            rowsStackView.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }
        footerHostView.subviews.forEach { $0.removeFromSuperview() }

        let sections = buildVisibleSections()
        var topDownRowViews: [UIView] = []

        if sections.isEmpty && isSearching {
            let emptyRow = makeSearchEmptyRow()
            rowsStackView.addArrangedSubview(emptyRow)
            topDownRowViews.append(emptyRow)
        } else {
            for (secIdx, section) in sections.enumerated() {
                if let header = section.header {
                    let headerView = makeSectionHeaderView(
                        title: header,
                        sectionID: section.id,
                        topPadding: secIdx == 0 ? 2 : 6
                    )
                    rowsStackView.addArrangedSubview(headerView)
                    topDownRowViews.append(headerView)
                }
                for item in section.items {
                    let rowControl = DockFilterRowControl(model: item, isDark: traitCollection.userInterfaceStyle == .dark)
                    rowsStackView.addArrangedSubview(rowControl)
                    topDownRowViews.append(rowControl)
                }
            }
        }

        if let footerModel = buildMoreFiltersFooterItem() {
            footerSeparator.isHidden = false
            footerHostView.isHidden = false
            let footerRow = DockFilterRowControl(model: footerModel, isDark: traitCollection.userInterfaceStyle == .dark)
            footerHostView.addSubview(footerRow)
            topDownRowViews.append(footerRow)
        } else {
            footerSeparator.isHidden = true
            footerHostView.isHidden = true
        }

        // 自底向上收集错峰槽位（越靠近 tabBar 的行越先上浮）
        var slots: [UIView] = Array(topDownRowViews.reversed())
        slots.append(searchBoxGlassView)
        slots.append(headerContainer)
        animatedSlotsBottomUp = slots

        let targetH = measureDesiredPanelHeight()
        targetExpandedBodyHeight = targetH
        layoutInternalContentCanvas(bodyHeight: targetH)
        if animateHeight && !DockMotion.isReduceMotionActive() && panelAnimator?.isRunning != true {
            springDriverView.transform = .identity
            springDriverView.bounds = CGRect(x: 0, y: 0, width: 100, height: currentRenderedBodyHeight)
            startMorphDisplayLink()
            let spring = UISpringTimingParameters(dampingRatio: 0.86)
            let anim = UIViewPropertyAnimator(duration: 0.24, timingParameters: spring)
            anim.addAnimations {
                self.springDriverView.bounds = CGRect(x: 0, y: 0, width: 100, height: targetH)
            }
            anim.addCompletion { [weak self] _ in
                guard let self, self.isExpanded else { return }
                self.stopMorphDisplayLink()
                self.currentRenderedBodyHeight = targetH
                self.renderUnionFrame(bodyHeight: targetH, scaleX: 1.0)
            }
            anim.startAnimation()
            panelAnimator = anim
        } else if panelAnimator?.isRunning != true {
            currentRenderedBodyHeight = targetH
            renderUnionFrame(bodyHeight: targetH, scaleX: currentRenderedScaleX)
        }
    }

    private func configureHeaderContent() {
        let battleVM = BattleListViewModel.shared
        let coopVM = CoopListViewModel.shared
        let homeSchedule = UserDefaults.standard.integer(forKey: "home_page_selectedScheduleType")

        let badge: String
        let title: String
        let status: String?
        let accent: UIColor

        switch activeTab {
        case .battle:
            if !battleVM.filter.rules.isEmpty,
               let first = battleVM.filter.rules.first,
               let rule = BattleRule(rawValue: first) {
                status = (rule == .turfWar) ? "涂地模式" : rule.name
            } else if battleVM.filter.modes.isEmpty {
                status = "全部"
            } else if battleVM.filter.modes.count == 1,
                      let raw = battleVM.filter.modes.first,
                      let mode = BattleMode(rawValue: raw) {
                status = mode.name
            } else {
                status = "已选 \(battleVM.filter.modes.count)"
            }
            badge = "对战"
            title = "模式与规则筛选"
            accent = UIColor(Color.spOrange)

        case .coop:
            if coopVM.isShowingShiftCards {
                status = "卡片视图"
            } else if coopVM.filter.rules.isEmpty {
                status = "全部"
            } else if coopVM.filter.rules.count == 1,
                      let raw = coopVM.filter.rules.first,
                      let rule = CoopRule(rawValue: raw) {
                status = rule.name
            } else {
                status = "已选 \(coopVM.filter.rules.count)"
            }
            badge = "鲑鱼跑"
            title = "规则筛选"
            accent = UIColor(Color.spGreen)

        case .home:
            badge = "主页"
            title = "日程与快筛"
            status = homeSchedule == 0 ? "对战日程" : "打工日程"
            accent = UIColor(Color.accentColor)

        case .me:
            badge = "我的"
            title = "战绩快捷入口"
            status = nil
            accent = UIColor(Color.spPurple)
        }

        headerBadgeLabel.text = badge
        headerBadgeLabel.textColor = accent
        headerBadgeBg.backgroundColor = accent.withAlphaComponent(0.16)
        headerTitleLabel.text = title
        headerStatusLabel.text = status
        headerStatusLabel.isHidden = (status == nil)
    }

    private func makeSectionHeaderView(title: String, sectionID: String, topPadding: CGFloat) -> UIView {
        let wrap = UIView()
        wrap.accessibilityIdentifier = "expandingDock.section.\(sectionID)"
        let label = UILabel()
        label.text = title
        label.font = Font.gameUIFont(size: 11)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: wrap.topAnchor, constant: topPadding),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -2),
        ])
        return wrap
    }

    private func makeSearchEmptyRow() -> UIView {
        let container = UIView()
        container.isAccessibilityElement = true
        container.accessibilityLabel = "没有匹配的筛选项"
        container.accessibilityIdentifier = "expandingDock.searchEmptyState"
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: DockConfig.panelRowHeight).isActive = true

        let badge = UIView()
        badge.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 8
        badge.layer.cornerCurve = .continuous
        badge.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(badge)

        let icon = UIImageView(
            image: UIImage(
                systemName: "magnifyingglass",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            )
        )
        icon.tintColor = .secondaryLabel
        icon.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(icon)

        let label = UILabel()
        label.text = "没有匹配的筛选项"
        label.font = Font.gameUIFont(size: 15)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            badge.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: DockConfig.panelIconSize),
            badge.heightAnchor.constraint(equalToConstant: DockConfig.panelIconSize),
            icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    // MARK: - 筛选项目录构建

    private func buildVisibleSections() -> [PanelSectionModel] {
        if isSearching {
            let matched = searchableCatalog().filter { item in
                DockSearchSupport.matches(query: searchQuery, candidates: [item.title] + item.keywords)
            }
            return matched.isEmpty ? [] : [PanelSectionModel(id: "search.results", header: nil, items: matched)]
        }

        var sections: [PanelSectionModel] = []
        let recents = buildRecentItems()
        if !recents.isEmpty {
            sections.append(PanelSectionModel(id: "section.recent", header: "最近使用", items: recents))
        }

        switch activeTab {
        case .battle:
            sections.append(
                PanelSectionModel(
                    id: "section.battleModes",
                    header: recents.isEmpty ? "对战模式" : "全部模式",
                    items: buildBattleModeItems()
                )
            )
            sections.append(
                PanelSectionModel(
                    id: "section.battleRules",
                    header: "对战规则",
                    items: buildBattleRuleItems()
                )
            )
        case .coop:
            sections.append(
                PanelSectionModel(
                    id: "section.coopRules",
                    header: recents.isEmpty ? nil : "打工规则",
                    items: buildCoopRuleItems()
                )
            )
        case .home:
            sections.append(PanelSectionModel(id: "section.home", header: nil, items: buildHomeQuickItems()))
        case .me:
            sections.append(PanelSectionModel(id: "section.me", header: nil, items: buildMeQuickItems()))
        }
        return sections
    }

    private func searchableCatalog() -> [PanelItemModel] {
        switch activeTab {
        case .battle:
            return buildBattleModeItems() + buildBattleRuleItems()
        case .coop:
            return buildCoopRuleItems()
        case .home:
            return buildHomeQuickItems()
                + buildBattleModeItems().filter { $0.id != "expandingDock.battleMode.ALL" }
                + buildBattleRuleItems()
                + buildCoopRuleItems().filter { $0.id != "expandingDock.coopRule.ALL_RULE" }
        case .me:
            return buildMeQuickItems()
                + buildBattleModeItems().filter { $0.id != "expandingDock.battleMode.ALL" }
                + buildBattleRuleItems()
                + buildCoopRuleItems().filter { $0.id != "expandingDock.coopRule.ALL_RULE" }
        }
    }

    private func buildRecentItems() -> [PanelItemModel] {
        let rawStorage = UserDefaults.standard.string(forKey: DockSearchSupport.recentModesStorageKey) ?? ""
        let keys = DockSearchSupport.parseRecentKeys(rawStorage)
        guard !keys.isEmpty else { return [] }

        let pool = buildBattleModeItems() + buildBattleRuleItems() + buildCoopRuleItems()
        var recents: [PanelItemModel] = []
        for key in keys {
            if activeTab == .battle && !key.hasPrefix("battle") { continue }
            if activeTab == .coop && !key.hasPrefix("coop") { continue }
            guard let base = pool.first(where: { $0.recentKey == key }) else { continue }
            recents.append(
                PanelItemModel(
                    id: "expandingDock.recent.\(key)",
                    recentKey: base.recentKey,
                    title: base.title,
                    keywords: base.keywords,
                    isSelected: base.isSelected,
                    isNavigation: false,
                    badgeCount: 0,
                    tintColor: base.tintColor,
                    iconImage: base.iconImage,
                    rendersAsTemplate: base.rendersAsTemplate,
                    action: base.action
                )
            )
            if recents.count >= DockSearchSupport.maxRecentCount { break }
        }
        return recents
    }

    private func recordRecentSelection(_ key: String) {
        let defaults = UserDefaults.standard
        let current = defaults.string(forKey: DockSearchSupport.recentModesStorageKey) ?? ""
        let updated = DockSearchSupport.recordRecentKey(key, into: current)
        defaults.set(updated, forKey: DockSearchSupport.recentModesStorageKey)
    }

    private func pickAndAutoCollapse(_ work: @escaping () async -> Void) {
        Haptics.generateIfEnabled(.selectionChanged)
        let hadKeyboard = searchTextField.isFirstResponder || keyboardOverlapHeight > 10
        if hadKeyboard {
            searchTextField.resignFirstResponder()
        }
        // 并发启动列表筛选查询：ViewModel 的 filter 与 navigationTitle 会在首个同步片段立即生效，
        // 面板在 75ms 视觉确认勾选后立即执行弹簧收起，绝不被大表 SQL 查询卡在半空。
        Task { @MainActor in
            await work()
        }
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.rebuildSections(animateHeight: false)
            try? await Task.sleep(for: .milliseconds(hadKeyboard ? 110 : 75))
            self?.collapse(reason: .pickedItem)
        }
    }

    private func closeAndPerformNavigation(_ block: @escaping () -> Void) {
        collapse(reason: .navigationAction)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            block()
        }
    }

    private func buildBattleModeItems() -> [PanelItemModel] {
        let battleVM = BattleListViewModel.shared
        return BattleMode.allCases.map { mode in
            let isSelected = battleVM.filter.rules.isEmpty && (
                mode == .all
                    ? battleVM.filter.modes.isEmpty
                    : battleVM.filter.modes.contains(mode.rawValue)
            )
            let keywords: [String] = {
                switch mode {
                case .all: return ["全部对战", "all"]
                case .regular: return ["一般比赛", "常规比赛", "涂地", "占地", "regular", "turfwar"]
                case .anarchy: return ["蛮颓比赛", "真格比赛", "挑战", "开放", "bankara", "anarchy"]
                case .xMatch: return ["X比赛", "X 比赛", "X比赛系列", "xmatch", "x"]
                case .league: return ["活动比赛", "活动", "league", "event"]
                case .privateMatch: return ["私人比赛", "私房", "private"]
                case .fest: return ["祭典比赛", "祭典", "splatfest", "fest"]
                }
            }()
            let recentKey: String? = (mode == .all) ? nil : "battleMode:\(mode.rawValue)"
            let icon: UIImage? = {
                switch mode {
                case .all:
                    return UIImage(
                        systemName: "square.grid.2x2.fill",
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                    )
                case .regular, .fest:
                    return UIImage(resource: .turfWar)
                case .anarchy:
                    return UIImage(resource: .anarchy)
                case .xMatch:
                    return UIImage(resource: .xBattle)
                case .league:
                    return UIImage(resource: .event)
                case .privateMatch:
                    return UIImage(resource: .private)
                }
            }()

            return PanelItemModel(
                id: "expandingDock.battleMode.\(mode.rawValue)",
                recentKey: recentKey,
                title: mode.name,
                keywords: keywords,
                isSelected: isSelected,
                isNavigation: false,
                badgeCount: 0,
                tintColor: UIColor(mode == .all ? .spOrange : mode.color),
                iconImage: icon,
                rendersAsTemplate: mode == .all
            ) { [weak self] in
                guard let self else { return }
                if let recentKey {
                    self.recordRecentSelection(recentKey)
                }
                self.pickAndAutoCollapse {
                    if self.activeTab != .battle {
                        self.onRequestTabSwitch?(.battle)
                    }
                    await BattleListViewModel.shared.selectModeFromDock(mode)
                }
            }
        }
    }

    private func buildBattleRuleItems() -> [PanelItemModel] {
        let battleVM = BattleListViewModel.shared
        return BattleRule.allCases.map { rule in
            let isSelected = battleVM.filter.modes.isEmpty && battleVM.filter.rules.contains(rule.rawValue)
            let displayTitle = (rule == .turfWar) ? "涂地模式" : rule.name
            let tint: UIColor = {
                switch rule {
                case .turfWar: return UIColor(Color.spLightGreen)
                case .splatZones, .towerControl, .rainmaker, .clamBlitz: return UIColor(Color.spOrange)
                case .triColor: return UIColor(Color.spPurple)
                }
            }()
            let keywords: [String] = {
                switch rule {
                case .turfWar: return ["涂地模式", "涂地", "占地对战", "占地", "turfwar", "tw"]
                case .splatZones: return ["真格区域", "区域", "占地真格", "splatzones", "area", "sz"]
                case .towerControl: return ["真格塔楼", "塔楼", "推塔", "towercontrol", "loft", "tc"]
                case .rainmaker: return ["真格鱼虎", "真格鱼虎对战", "鱼虎", "抢鱼", "rainmaker", "goal", "rm"]
                case .clamBlitz: return ["真格蛤蜊", "蛤蜊", "投蛤", "clamblitz", "clam", "cb"]
                case .triColor: return ["三色夺宝对战", "三色", "三色夺宝", "tricolor"]
                }
            }()
            let icon: UIImage = {
                switch rule {
                case .clamBlitz: return UIImage(resource: .clamBlitz)
                case .rainmaker: return UIImage(resource: .rainmaker)
                case .splatZones: return UIImage(resource: .splatZones)
                case .towerControl: return UIImage(resource: .towerControl)
                case .turfWar: return UIImage(resource: .turfWar)
                case .triColor: return UIImage(resource: .league)
                }
            }()
            let recentKey = "battleRule:\(rule.rawValue)"

            return PanelItemModel(
                id: "expandingDock.battleRule.\(rule.rawValue)",
                recentKey: recentKey,
                title: displayTitle,
                keywords: [rule.name] + keywords,
                isSelected: isSelected,
                isNavigation: false,
                badgeCount: 0,
                tintColor: tint,
                iconImage: icon,
                rendersAsTemplate: false
            ) { [weak self] in
                guard let self else { return }
                self.recordRecentSelection(recentKey)
                self.pickAndAutoCollapse {
                    if self.activeTab != .battle {
                        self.onRequestTabSwitch?(.battle)
                    }
                    await BattleListViewModel.shared.selectRuleFromDock(rule)
                }
            }
        }
    }

    private func buildCoopRuleItems() -> [PanelItemModel] {
        let coopVM = CoopListViewModel.shared
        var items: [PanelItemModel] = CoopRule.allCases.map { rule in
            let isSelected = !coopVM.isShowingShiftCards && (
                rule == .ALL
                    ? coopVM.filter.rules.isEmpty
                    : coopVM.filter.rules.contains(rule.rawValue)
            )
            let tint: UIColor = {
                switch rule {
                case .ALL, .REGULAR: return UIColor(Color.spGreen)
                case .BIG_RUN: return UIColor(Color.spPurple)
                case .TEAM_CONTEST: return UIColor(Color.spOrange)
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
            let icon: UIImage? = {
                switch rule {
                case .ALL:
                    return UIImage(
                        systemName: "square.grid.2x2.fill",
                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                    )
                case .REGULAR:
                    return UIImage(resource: .salmonRun)
                case .BIG_RUN:
                    return UIImage(resource: .coopBigrun)
                case .TEAM_CONTEST:
                    return UIImage(resource: .coopTeamContest)
                }
            }()
            let recentKey: String? = (rule == .ALL) ? nil : "coopRule:\(rule.rawValue)"

            return PanelItemModel(
                id: "expandingDock.coopRule.\(rule.rawValue)",
                recentKey: recentKey,
                title: rule.name,
                keywords: keywords,
                isSelected: isSelected,
                isNavigation: false,
                badgeCount: 0,
                tintColor: tint,
                iconImage: icon,
                rendersAsTemplate: rule == .ALL
            ) { [weak self] in
                guard let self else { return }
                if let recentKey {
                    self.recordRecentSelection(recentKey)
                }
                self.pickAndAutoCollapse {
                    if self.activeTab != .coop {
                        self.onRequestTabSwitch?(.coop)
                    }
                    await CoopListViewModel.shared.selectRuleFromDock(rule)
                }
            }
        }

        items.append(
            PanelItemModel(
                id: "expandingDock.coopRule.SHIFT_CARDS",
                recentKey: "coopMode:SHIFT_CARDS",
                title: "打工卡片",
                keywords: ["打工卡片", "班次卡片", "shiftcards", "cards"],
                isSelected: coopVM.isShowingShiftCards,
                isNavigation: false,
                badgeCount: 0,
                tintColor: UIColor(Color.spYellow),
                iconImage: UIImage(
                    systemName: "rectangle.stack.fill",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                ),
                rendersAsTemplate: true
            ) { [weak self] in
                guard let self else { return }
                self.recordRecentSelection("coopMode:SHIFT_CARDS")
                self.pickAndAutoCollapse {
                    if self.activeTab != .coop {
                        self.onRequestTabSwitch?(.coop)
                    }
                    await CoopListViewModel.shared.selectShiftCardsFromDock()
                }
            }
        )
        return items
    }

    private func buildHomeQuickItems() -> [PanelItemModel] {
        let scheduleType = UserDefaults.standard.integer(forKey: "home_page_selectedScheduleType")
        let filterSym = UIImage(
            systemName: "line.3.horizontal.decrease.circle",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )
        return [
            PanelItemModel(
                id: "expandingDock.home.battleSchedule",
                recentKey: nil,
                title: "对战日程",
                keywords: ["对战日程", "日程", "schedule", "battle"],
                isSelected: scheduleType == 0,
                isNavigation: false,
                badgeCount: 0,
                tintColor: UIColor(Color.spOrange),
                iconImage: UIImage(resource: .anarchy),
                rendersAsTemplate: false
            ) { [weak self] in
                self?.pickAndAutoCollapse {
                    UserDefaults.standard.set(0, forKey: "home_page_selectedScheduleType")
                }
            },
            PanelItemModel(
                id: "expandingDock.home.coopSchedule",
                recentKey: nil,
                title: "鲑鱼跑日程",
                keywords: ["鲑鱼跑日程", "打工日程", "salmonrun", "coop"],
                isSelected: scheduleType == 1,
                isNavigation: false,
                badgeCount: 0,
                tintColor: UIColor(Color.spGreen),
                iconImage: UIImage(resource: .salmonRun),
                rendersAsTemplate: false
            ) { [weak self] in
                self?.pickAndAutoCollapse {
                    UserDefaults.standard.set(1, forKey: "home_page_selectedScheduleType")
                }
            },
            PanelItemModel(
                id: "expandingDock.home.gotoBattleFilter",
                recentKey: nil,
                title: "去对战筛选页设置条件…",
                keywords: ["对战筛选", "更多条件"],
                isSelected: false,
                isNavigation: true,
                badgeCount: BattleListViewModel.shared.extraActiveFilterCount,
                tintColor: UIColor(Color.spOrange),
                iconImage: filterSym,
                rendersAsTemplate: true
            ) { [weak self] in
                self?.closeAndPerformNavigation {
                    self?.onRequestTabSwitch?(.battle)
                    BattleListViewModel.shared.showFilterSheet = true
                }
            },
            PanelItemModel(
                id: "expandingDock.home.gotoCoopFilter",
                recentKey: nil,
                title: "去打工筛选页设置条件…",
                keywords: ["打工筛选", "更多条件"],
                isSelected: false,
                isNavigation: true,
                badgeCount: CoopListViewModel.shared.extraActiveFilterCount,
                tintColor: UIColor(Color.spGreen),
                iconImage: filterSym,
                rendersAsTemplate: true
            ) { [weak self] in
                self?.closeAndPerformNavigation {
                    self?.onRequestTabSwitch?(.coop)
                    CoopListViewModel.shared.showFilterSheet = true
                }
            },
        ]
    }

    private func buildMeQuickItems() -> [PanelItemModel] {
        let specs: [(String, String, [String], String, UIColor, String)] = [
            ("expandingDock.me.weapon", "武器榜", ["武器榜", "weapon"], "scope", UIColor(Color.spOrange), "weapon"),
            ("expandingDock.me.stage", "场地榜", ["场地榜", "地图", "stage"], "map.fill", UIColor(Color.spLightGreen), "stage"),
            ("expandingDock.me.coop", "打工记录统计", ["打工记录统计", "统计", "coop"], "drop.fill", UIColor(Color.spGreen), "coop"),
            ("expandingDock.me.trash", "记录回收站", ["回收站", "已删除", "trash"], "trash.fill", UIColor(Color.spPink), "trash"),
            ("expandingDock.me.settings", "账号与偏好设置", ["设置", "偏好", "settings"], "gearshape.fill", UIColor(Color.accentColor), "settings"),
        ]
        return specs.map { id, title, keywords, symbol, tint, dest in
            PanelItemModel(
                id: id,
                recentKey: nil,
                title: title,
                keywords: keywords,
                isSelected: false,
                isNavigation: true,
                badgeCount: 0,
                tintColor: tint,
                iconImage: UIImage(
                    systemName: symbol,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                ),
                rendersAsTemplate: true
            ) { [weak self] in
                self?.closeAndPerformNavigation {
                    DockVisibilityStore.shared.meDestination = dest
                }
            }
        }
    }

    private func buildMoreFiltersFooterItem() -> PanelItemModel? {
        let sliderImg = UIImage(
            systemName: "slider.horizontal.3",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )
        switch activeTab {
        case .battle:
            return PanelItemModel(
                id: "expandingDock.battle.moreFilters",
                recentKey: nil,
                title: "去筛选页设置更多条件…",
                keywords: [],
                isSelected: false,
                isNavigation: true,
                badgeCount: BattleListViewModel.shared.extraActiveFilterCount,
                tintColor: UIColor(Color.spOrange),
                iconImage: sliderImg,
                rendersAsTemplate: true
            ) { [weak self] in
                self?.closeAndPerformNavigation {
                    BattleListViewModel.shared.showFilterSheet = true
                }
            }
        case .coop:
            return PanelItemModel(
                id: "expandingDock.coop.moreFilters",
                recentKey: nil,
                title: "去筛选页设置更多条件…",
                keywords: [],
                isSelected: false,
                isNavigation: true,
                badgeCount: CoopListViewModel.shared.extraActiveFilterCount,
                tintColor: UIColor(Color.spGreen),
                iconImage: sliderImg,
                rendersAsTemplate: true
            ) { [weak self] in
                self?.closeAndPerformNavigation {
                    CoopListViewModel.shared.showFilterSheet = true
                }
            }
        case .home, .me:
            return nil
        }
    }
}

// MARK: - 5. 统一 40pt 行高 UIKit 按钮控件（单选行仅显示 ✓ 无 ›，导航行显示 ›）

@MainActor
private final class DockFilterRowControl: UIControl {
    private let model: DockFilterPanelViewController.PanelItemModel
    private let isDark: Bool
    private let highlightPill = UIView()
    private let iconBadge = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let countBadge = UILabel()
    private let trailingSymbol = UIImageView()

    init(model: DockFilterPanelViewController.PanelItemModel, isDark: Bool) {
        self.model = model
        self.isDark = isDark
        super.init(frame: .zero)
        setupRow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: DockConfig.panelRowHeight)
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            let anim = UIViewPropertyAnimator(duration: 0.09, curve: .easeOut)
            anim.addAnimations {
                if self.isHighlighted {
                    self.highlightPill.backgroundColor = UIColor.label.withAlphaComponent(self.isDark ? 0.14 : 0.08)
                    if !DockMotion.isReduceMotionActive() {
                        self.transform = CGAffineTransform(scaleX: 0.985, y: 0.985)
                    }
                } else {
                    self.applyRestingBackground()
                    self.transform = .identity
                }
            }
            anim.startAnimation()
        }
    }

    private func setupRow() {
        let accent = UIColor(Color.accentColor)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: DockConfig.panelRowHeight).isActive = true

        isAccessibilityElement = true
        accessibilityLabel = model.title
        accessibilityIdentifier = model.id
        accessibilityTraits = model.isSelected ? [.button, .selected] : [.button]

        highlightPill.isUserInteractionEnabled = false
        highlightPill.layer.cornerRadius = 12
        highlightPill.layer.cornerCurve = .continuous
        highlightPill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(highlightPill)
        applyRestingBackground()

        iconBadge.isUserInteractionEnabled = false
        iconBadge.backgroundColor = model.tintColor.withAlphaComponent(model.isSelected ? 0.22 : 0.14)
        iconBadge.layer.cornerRadius = 8
        iconBadge.layer.cornerCurve = .continuous
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconBadge)

        iconView.contentMode = .scaleAspectFit
        if model.rendersAsTemplate {
            iconView.image = model.iconImage?.withRenderingMode(.alwaysTemplate)
            iconView.tintColor = model.isSelected ? accent : model.tintColor
        } else {
            iconView.image = model.iconImage?.withRenderingMode(.alwaysOriginal)
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconView)

        titleLabel.text = model.title
        titleLabel.font = Font.gameUIFont(size: model.isNavigation ? 12 : 15)
        titleLabel.textColor = model.isSelected ? accent : UIColor(Color.appLabel)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.85
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        trailingSymbol.contentMode = .scaleAspectFit
        trailingSymbol.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trailingSymbol)

        if model.isNavigation {
            // 导航行显示右侧 › chevron 及可选附加条件徽标
            trailingSymbol.image = UIImage(
                systemName: "chevron.right",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            )
            trailingSymbol.tintColor = UIColor.secondaryLabel.withAlphaComponent(0.65)
            trailingSymbol.isHidden = false
        } else if model.isSelected {
            // 单选模式/规则行：选中态只显示 ✓，绝不显示 ›
            trailingSymbol.image = UIImage(
                systemName: "checkmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            )
            trailingSymbol.tintColor = accent
            trailingSymbol.isHidden = false
        } else {
            trailingSymbol.isHidden = true
        }

        countBadge.font = Font.gameUIFont(size: 11)
        countBadge.textColor = accent
        countBadge.backgroundColor = accent.withAlphaComponent(0.16)
        countBadge.textAlignment = .center
        countBadge.layer.cornerRadius = 9
        countBadge.clipsToBounds = true
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(countBadge)

        if model.badgeCount > 0 {
            countBadge.text = "  \(model.badgeCount)  "
            countBadge.isHidden = false
        } else {
            countBadge.isHidden = true
        }

        NSLayoutConstraint.activate([
            highlightPill.leadingAnchor.constraint(equalTo: leadingAnchor),
            highlightPill.trailingAnchor.constraint(equalTo: trailingAnchor),
            highlightPill.topAnchor.constraint(equalTo: topAnchor),
            highlightPill.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBadge.widthAnchor.constraint(equalToConstant: DockConfig.panelIconSize),
            iconBadge.heightAnchor.constraint(equalToConstant: DockConfig.panelIconSize),

            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),

            trailingSymbol.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            trailingSymbol.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingSymbol.widthAnchor.constraint(equalToConstant: 16),
            trailingSymbol.heightAnchor.constraint(equalToConstant: 16),

            countBadge.trailingAnchor.constraint(equalTo: trailingSymbol.leadingAnchor, constant: -6),
            countBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            countBadge.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: model.badgeCount > 0 ? countBadge.leadingAnchor : trailingSymbol.leadingAnchor,
                constant: -6
            ),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        addAction(UIAction { [weak self] _ in
            self?.model.action()
        }, for: .touchUpInside)
    }

    private func applyRestingBackground() {
        let accent = UIColor(Color.accentColor)
        if model.isSelected && !model.isNavigation {
            highlightPill.backgroundColor = accent.withAlphaComponent(isDark ? 0.22 : 0.13)
            highlightPill.layer.borderWidth = 0.75
            highlightPill.layer.borderColor = accent.withAlphaComponent(0.26).cgColor
        } else {
            highlightPill.backgroundColor = .clear
            highlightPill.layer.borderWidth = 0
            highlightPill.layer.borderColor = nil
        }
    }
}
