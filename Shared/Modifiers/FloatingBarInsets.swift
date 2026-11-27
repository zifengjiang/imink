import SwiftUI
import UIKit
import Combine

/// 可展开底部 Dock 的全局几何常量与开关配置（4pt 栅格）。
enum DockConfig {
    /// 兜底开关 `@AppStorage` 键名：`true` 使用自绘 `ExpandingDock`，`false` 回退系统 `TabView`。
    static let storageKey = "imink.useCustomDock"

    /// 收起态胶囊高度（严格 `<= 49pt`，4pt 栅格，比 iOS 26 系统浮动栏 62pt 薄 14pt）。
    static let collapsedHeight: CGFloat = 48

    /// 容器圆角（`collapsedHeight / 2`，收起态即为居中对称 4-Tab 标准胶囊，展开态同源过渡为圆角面板）。
    static let cornerRadius: CGFloat = 24

    /// 内部选中 Tab 滑块高度与内边距（`24 - 4 = 20pt` 同心圆角）。
    static let tabPillHeight: CGFloat = 40
    static let tabPillInset: CGFloat = 4

    /// 展开态单行高度、图标块尺寸与面板内边距（40pt 行高确保 7 项对战模式 + 更多筛选 + 底部胶囊把手一屏完整放下）。
    static let panelRowHeight: CGFloat = 40
    static let panelIconSize: CGFloat = 28
    static let panelPadding: CGFloat = 8

    /// 屏幕两侧对称水平外边距与大屏（iPad / 横屏）最大总宽限制（取消第 5 颗右圆钮，恢复居中对称 4-Tab 胶囊）。
    static let horizontalMargin: CGFloat = 20
    static let maxDockWidth: CGFloat = 368

    /// 当前是否启用自绘 `ExpandingDock`（默认 `true`）。
    @MainActor static var isCustomDockEnabled: Bool {
        (UserDefaults.standard.object(forKey: storageKey) as? Bool) ?? true
    }

    /// Dock 底沿距屏幕物理底边的距离：有 Home Indicator 机型悬停在指示条上方（34pt 安全区下为 20pt），无安全区机型留 12pt。
    static func bottomMargin(safeAreaBottom: CGFloat) -> CGFloat {
        safeAreaBottom > 0 ? max(safeAreaBottom - 14, 16) : 12
    }

    /// 未完成首帧几何实测前，自绘 Dock 收起态顶沿距屏幕物理底边的默认高度（标准 Face ID 机型：`20 + 48 = 68pt`）。
    static func defaultCustomDockTop(safeAreaBottom: CGFloat) -> CGFloat {
        bottomMargin(safeAreaBottom: safeAreaBottom) + collapsedHeight
    }
}

/// 可展开 Dock 的三态状态机。
enum DockState: String, Equatable {
    /// 常驻轻薄胶囊（4 个 Tab + 右侧圆形展开按钮）
    case collapsed
    /// 向上弹开成模式快筛 + 更多条件面板 + 背景变暗遮罩
    case expanded
    /// 向下连续滚动列表时自动下移退让
    case scrollingHidden
}

/// 跨页面共享的 Dock 状态与滚动退让协调器。
@MainActor
final class DockVisibilityStore: ObservableObject {
    static let shared = DockVisibilityStore()

    @Published var state: DockState = .collapsed
    /// 手势下拉面板时的归一化收起进度（`0` 完全展开，`1` 拉到底），用于联动背景模糊半径。
    @Published var dragDismissProgress: CGFloat = 0
    /// 「我」页快捷面板触发的二级导航目标标识。
    @Published var meDestination: String = ""
    /// 收起态下 Dock 胶囊 + 右圆钮在全屏容器坐标中的可点击热区（不加 `@Published` 避免触发重绘循环）。
    var collapsedHitRect: CGRect = .zero

    private var accumulatedScrollDelta: CGFloat = 0

    var isExpanded: Bool {
        state == .expanded
    }

    func toggleExpanded() {
        accumulatedScrollDelta = 0
        dragDismissProgress = 0
        state = (state == .expanded) ? .collapsed : .expanded
    }

    func expand() {
        accumulatedScrollDelta = 0
        dragDismissProgress = 0
        state = .expanded
    }

    func collapse() {
        accumulatedScrollDelta = 0
        dragDismissProgress = 0
        if state != .collapsed {
            state = .collapsed
        }
    }

    /// 被动监听主列表 `contentOffset.y` 变化，实现无手势侵入的向下滚动收起、向上回滚/触底恢复。
    func handleScrollChange(
        oldY: CGFloat,
        newY: CGFloat,
        contentHeight: CGFloat,
        containerHeight: CGFloat
    ) {
        guard state != .expanded else { return }

        // 内容不足以长距离滚动、位于列表顶部、或已接近列表底部时，始终保持常驻可见
        let scrollableDistance = contentHeight - containerHeight
        let isNearTop = newY <= 24
        let isNearBottom = scrollableDistance > 0 && (newY >= scrollableDistance - 36)
        if scrollableDistance < 96 || isNearTop || isNearBottom {
            accumulatedScrollDelta = 0
            if state == .scrollingHidden {
                state = .collapsed
            }
            return
        }

        let delta = newY - oldY
        guard abs(delta) < 240 else { return } // 忽略数据源切换引发的大跨度跳变

        if (delta > 0 && accumulatedScrollDelta < 0) || (delta < 0 && accumulatedScrollDelta > 0) {
            accumulatedScrollDelta = 0
        }
        accumulatedScrollDelta += delta

        if newY > 96, accumulatedScrollDelta > 28, state == .collapsed {
            state = .scrollingHidden
            accumulatedScrollDelta = 0
        } else if accumulatedScrollDelta < -12, state == .scrollingHidden {
            state = .collapsed
            accumulatedScrollDelta = 0
        }
    }
}

/// 悬浮栏（顶部导航工具栏 + 底部浮动栏/自绘 ExpandingDock）统一避让常量与修饰器。
///
/// 设计原则：
/// 1. 同时兼容两套底栏路径：
///    - 自绘 `ExpandingDock`（`imink.useCustomDock == true`，默认）：收起态本体高 `48pt`，距屏幕底 `20pt`，
///      顶沿位于 `68pt`（实测值写入 `measuredCustomDockTop`），比系统胶囊省出 `15pt` 纵向内容空间；
///    - 原生系统 `TabView`（`imink.useCustomDock == false`）：浮动胶囊顶沿位于约 `83pt`（实测值写入 `measuredSystemTabBarTop`）。
/// 2. 所有页面通过 `.floatingTabBarInset()`（或自动继承自 `.fixSafeareaBackground()`）仅注入 **透明** `Color.clear`
///    净空，保证滑到底部时最后一张卡片停在当前生效底栏顶沿上方统一的 `8pt`（`breathingSpacing`）处，既不压到 Dock 底下，也不留实心空白带；
/// 3. 通过 `@Environment(\.hasFloatingTabBarInset)` 防止父子容器嵌套时重复叠加底部留白。
enum FloatingBarInsets {
    /// 系统浮动胶囊 Tab 栏实测本体高度
    static let systemTabBarHeight: CGFloat = 62

    /// 当前生效底栏的本体高度（自绘 Dock 为 48pt，系统 Tab 栏为 62pt）
    @MainActor static var tabBarHeight: CGFloat {
        DockConfig.isCustomDockEnabled ? DockConfig.collapsedHeight : systemTabBarHeight
    }

    /// 卡片底部与浮动栏顶沿之间的统一呼吸间距（4pt 栅格）
    static let breathingSpacing: CGFloat = 8

    /// 原生系统 `TabView` 实测到的胶囊顶沿高度（距屏幕物理底边，含 Home Indicator）。
    @MainActor static var measuredSystemTabBarTop: CGFloat = 0

    /// 自绘 `ExpandingDock` 收起态实测到的胶囊顶沿高度（距屏幕物理底边，含 Home Indicator）。
    @MainActor static var measuredCustomDockTop: CGFloat = 0

    /// 当前生效底栏的实测顶沿高度（按 `imink.useCustomDock` 自动路由读写）。
    @MainActor static var measuredTabBarTop: CGFloat {
        get {
            DockConfig.isCustomDockEnabled ? measuredCustomDockTop : measuredSystemTabBarTop
        }
        set {
            if DockConfig.isCustomDockEnabled {
                measuredCustomDockTop = newValue
            } else {
                measuredSystemTabBarTop = newValue
            }
        }
    }

    /// 当前生效底栏顶沿距屏幕物理底边的高度：优先用实测值，未测量前按当前模式回退标准值（自绘 Dock 68pt / 系统栏 83pt）。
    @MainActor static var tabBarTopFromScreenBottom: CGFloat {
        if DockConfig.isCustomDockEnabled {
            if measuredCustomDockTop > 0 {
                return measuredCustomDockTop
            }
            return DockConfig.defaultCustomDockTop(safeAreaBottom: safeArea.bottom)
        } else {
            if measuredSystemTabBarTop > 0 {
                return measuredSystemTabBarTop
            }
            return max(safeArea.bottom + 49, 83)
        }
    }

    /// 顶部：安全区 + 悬浮导航工具栏高度（用于完全 ignoresSafeArea 的全屏滚动容器）
    @MainActor static var top: CGFloat { safeArea.top + 56 }

    /// 底部：当前底栏顶沿高度 + 统一呼吸间距（用于完全 ignoresSafeArea 的全屏滚动容器，不重复计算 safeArea.bottom）
    @MainActor static var bottom: CGFloat { tabBarTopFromScreenBottom + breathingSpacing }

    @MainActor static var safeArea: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    }
}

private struct HasFloatingTabBarInsetKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var hasFloatingTabBarInset: Bool {
        get { self[HasFloatingTabBarInsetKey.self] }
        set { self[HasFloatingTabBarInsetKey.self] = newValue }
    }
}

/// 为滚动容器（`ScrollView` / `List`）注入统一的浮动底栏透明 `safeAreaInset`，并在自定义 Dock 启用时隐藏系统 `UITabBar`。
struct FloatingTabBarInsetModifier: ViewModifier {
    @Environment(\.hasFloatingTabBarInset) private var hasApplied
    @AppStorage(DockConfig.storageKey) private var useCustomDock: Bool = true
    @State private var containerBottomInset: CGFloat = 0

    /// 除系统已经给出的 `safeAreaInsets.bottom` 外，还要补齐的透明净空：
    /// - 自绘 Dock 模式：系统仅给出 Home Indicator（如 34pt），补齐到 `68 + 8 = 76pt`（差额 42pt）；
    /// - 系统 TabView 模式：系统已给出胶囊顶沿（如 83pt），仅补 `breathingSpacing`（8pt），总计 91pt。
    private var extraBottomInset: CGFloat {
        let barTop: CGFloat
        if useCustomDock {
            barTop = FloatingBarInsets.measuredCustomDockTop > 0
                ? FloatingBarInsets.measuredCustomDockTop
                : DockConfig.defaultCustomDockTop(safeAreaBottom: FloatingBarInsets.safeArea.bottom)
        } else {
            barTop = FloatingBarInsets.measuredSystemTabBarTop > 0
                ? FloatingBarInsets.measuredSystemTabBarTop
                : max(FloatingBarInsets.safeArea.bottom + 49, 83)
        }
        let targetFromScreenBottom = max(containerBottomInset, barTop) + FloatingBarInsets.breathingSpacing
        guard containerBottomInset > 0 else {
            return targetFromScreenBottom
        }
        return max(
            FloatingBarInsets.breathingSpacing,
            targetFromScreenBottom - containerBottomInset
        )
    }

    func body(content: Content) -> some View {
        if hasApplied {
            content
        } else {
            content
                .toolbar(useCustomDock ? .hidden : .visible, for: .tabBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: extraBottomInset)
                        .allowsHitTesting(false)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.bottom
                } action: { outerBottom in
                    // 仅在系统 TabView 启用且实测值高于纯 Home Indicator 安全区时，记录系统胶囊顶沿高度
                    if !useCustomDock, outerBottom > FloatingBarInsets.safeArea.bottom + 10 {
                        FloatingBarInsets.measuredSystemTabBarTop = outerBottom
                    }
                    if outerBottom >= 0, abs(outerBottom - containerBottomInset) > 0.5 {
                        containerBottomInset = outerBottom
                    }
                }
                .environment(\.hasFloatingTabBarInset, true)
        }
    }
}

/// 按"系统已经给了多少 inset"补齐差额（用于显式传入 `EdgeInsets` 的全屏容器）。
struct FloatingBarPadding: ViewModifier {
    let currentInsets: EdgeInsets
    @AppStorage(DockConfig.storageKey) private var useCustomDock: Bool = true

    func body(content: Content) -> some View {
        let _ = useCustomDock
        content
            .toolbar(useCustomDock ? .hidden : .visible, for: .tabBar)
            .padding(.top, max(0, FloatingBarInsets.top - currentInsets.top))
            .padding(.bottom, max(0, FloatingBarInsets.bottom - currentInsets.bottom))
            .environment(\.hasFloatingTabBarInset, true)
    }
}

/// 全量避让修饰器（适用于 `ignoresSafeArea(edges: .vertical)` 的详情页骨架，随 `useCustomDock` 实时响应）。
private struct FullFloatingBarClearanceModifier: ViewModifier {
    @AppStorage(DockConfig.storageKey) private var useCustomDock: Bool = true

    func body(content: Content) -> some View {
        let _ = useCustomDock
        content
            .toolbar(useCustomDock ? .hidden : .visible, for: .tabBar)
            .padding(.top, FloatingBarInsets.top)
            .padding(.bottom, FloatingBarInsets.bottom)
            .environment(\.hasFloatingTabBarInset, true)
    }
}

private struct ScrollGeometrySnapshot: Equatable {
    let offsetY: CGFloat
    let contentHeight: CGFloat
    let containerHeight: CGFloat
}

/// 被动监听 `ScrollView` 纵向滚动以驱动 `ExpandingDock` 收起/恢复（零手势冲突）。
private struct DockScrollMinimizeModifier: ViewModifier {
    @AppStorage(DockConfig.storageKey) private var useCustomDock: Bool = true

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: ScrollGeometrySnapshot.self) { geo in
            ScrollGeometrySnapshot(
                offsetY: geo.contentOffset.y + geo.contentInsets.top,
                contentHeight: geo.contentSize.height,
                containerHeight: geo.containerSize.height
            )
        } action: { oldValue, newValue in
            guard useCustomDock else { return }
            DockVisibilityStore.shared.handleScrollChange(
                oldY: oldValue.offsetY,
                newY: newValue.offsetY,
                contentHeight: newValue.contentHeight,
                containerHeight: newValue.containerHeight
            )
        }
    }
}

extension View {
    /// 为各 Tab 及二级页面的 `ScrollView` / `List` 统一预留浮动底栏透明净空。
    func floatingTabBarInset() -> some View {
        modifier(FloatingTabBarInsetModifier())
    }

    /// 滚动内容让开顶部悬浮栏与底部栏（差额补齐版）。
    func clearFloatingBars(currentInsets: EdgeInsets) -> some View {
        modifier(FloatingBarPadding(currentInsets: currentInsets))
    }

    /// 滚动内容让开栏位（全量版，适用于 `ignoresSafeArea(edges: .vertical)` 的详情页骨架）。
    func clearFloatingBars() -> some View {
        modifier(FullFloatingBarClearanceModifier())
    }

    /// 让主列表滚动时自动通知 `ExpandingDock` 收起或恢复。
    func dockScrollMinimizeObserver() -> some View {
        modifier(DockScrollMinimizeModifier())
    }
}
