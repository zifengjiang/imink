import SwiftUI
import UIKit

/// 悬浮栏（顶部导航工具栏 + 底部 Liquid Glass 浮动 Tab 栏）统一避让常量与修饰器。
///
/// 设计原则：
/// 1. 实测 iOS 26/27 浮动胶囊 Tab 栏位于距屏幕底边 21pt~83pt 区间（本体高约 62pt，系统 `TabView` 已将容器
///    `safeAreaInsets.bottom` 设为胶囊顶沿高度 `83pt`，内含 Home Indicator 区域，严禁再把 `64pt` 重复叠加到 `34pt` 之上）；
/// 2. 所有页面通过 `.floatingTabBarInset()`（或自动继承自 `.fixSafeareaBackground()`）仅注入 **透明** `Color.clear`
///    呼吸净空（`8pt`），既让滚动过程中的内容自然穿过半透明 Liquid Glass 胶囊背面（消除底部实心灰块“空白占位”），
///    又保证滑到底部时最后一张卡片停在浮动 Tab 栏顶沿上方统一的 `8pt` 呼吸距离处；
/// 3. 通过 `@Environment(\.hasFloatingTabBarInset)` 防止父子容器嵌套时重复叠加底部留白。
enum FloatingBarInsets {
    /// 浮动胶囊 Tab 栏实测本体高度（21pt ~ 83pt）
    static let tabBarHeight: CGFloat = 62

    /// 卡片底部与浮动 Tab 栏顶沿之间的统一呼吸间距（4pt 栅格）
    static let breathingSpacing: CGFloat = 8

    /// 滚动容器 `onGeometryChange` 实测到的胶囊顶沿高度（距屏幕物理底边，含 Home Indicator）。
    /// - 系统 `TabView` 把自己的 `safeAreaInsets.bottom` 设成胶囊顶沿高度，直接在容器上量即可，
    ///   不再写死 `83pt`；只有还没量到（首帧 / 非 TabView 全屏容器）时才用系统标准值兜底。
    @MainActor static var measuredTabBarTop: CGFloat = 0

    /// 浮动胶囊 Tab 栏顶沿距屏幕物理底边的高度：优先用实测值，未测量前回落系统标准 83pt。
    @MainActor static var tabBarTopFromScreenBottom: CGFloat {
        if measuredTabBarTop > 0 {
            return measuredTabBarTop
        }
        return max(safeArea.bottom + 49, 83)
    }

    /// 顶部：安全区 + 悬浮导航工具栏高度（用于完全 ignoresSafeArea 的全屏滚动容器）
    @MainActor static var top: CGFloat { safeArea.top + 56 }

    /// 底部：浮动 Tab 栏顶沿高度 + 统一呼吸间距（用于完全 ignoresSafeArea 的全屏滚动容器，不重复计算 safeArea.bottom）
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

/// 为滚动容器（`ScrollView` / `List`）注入统一的浮动 Tab 栏底部透明 `safeAreaInset`。
///
/// 自动读取当前容器已有的 `safeAreaInsets.bottom`：
/// - 实测系统 `TabView` 注入的胶囊顶沿高度（`onGeometryChange` 读 `safeAreaInsets.bottom`），只补 `8pt` 透明呼吸净空；
/// - 若因 `.tabBarMinimizeBehavior(.onScrollDown)` 或全屏容器还没量到 inset，则在首帧补齐到「胶囊顶沿 + 8pt」，随后收敛到 8pt；
/// - 严禁使用不透明背景色填充 `safeAreaInset`，否则会在未滑到底部时在 Tab 栏上方形成遮挡内容的空白色带。
struct FloatingTabBarInsetModifier: ViewModifier {
    @Environment(\.hasFloatingTabBarInset) private var hasApplied
    @State private var containerBottomInset: CGFloat = 0

    /// 除系统已经给出的胶囊净空外，还要补的透明净空。
    /// - 系统已给（列表在 `TabView` 内，`safeAreaInsets.bottom == 胶囊顶沿高度`）：只补 `breathingSpacing`（8pt）；
    /// - 还没量到（0）：按实测/兜底的胶囊顶沿 + 8pt 补齐，避免首帧内容被胶囊盖住。
    private var extraBottomInset: CGFloat {
        guard containerBottomInset > 0 else {
            return FloatingBarInsets.tabBarTopFromScreenBottom + FloatingBarInsets.breathingSpacing
        }
        let targetFromScreenBottom = containerBottomInset + FloatingBarInsets.breathingSpacing
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
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: extraBottomInset)
                        .allowsHitTesting(false)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.bottom
                } action: { outerBottom in
                    if outerBottom > 0 {
                        // 实测胶囊顶沿高度写回统一常量，供全屏容器（`clearFloatingBars()`）共用，不再写死 83pt
                        FloatingBarInsets.measuredTabBarTop = outerBottom
                    }
                    if outerBottom > 0, abs(outerBottom - containerBottomInset) > 0.5 {
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

    func body(content: Content) -> some View {
        content
            .padding(.top, max(0, FloatingBarInsets.top - currentInsets.top))
            .padding(.bottom, max(0, FloatingBarInsets.bottom - currentInsets.bottom))
            .environment(\.hasFloatingTabBarInset, true)
    }
}

extension View {
    /// 为各 Tab 及二级页面的 `ScrollView` / `List` 统一预留浮动 Tab 栏底部净空。
    func floatingTabBarInset() -> some View {
        modifier(FloatingTabBarInsetModifier())
    }

    /// 滚动内容让开顶部悬浮栏与底部 Tab 栏（差额补齐版）。
    func clearFloatingBars(currentInsets: EdgeInsets) -> some View {
        modifier(FloatingBarPadding(currentInsets: currentInsets))
    }

    /// 滚动内容让开栏位（全量版，适用于 `ignoresSafeArea(edges: .vertical)` 的详情页骨架）。
    func clearFloatingBars() -> some View {
        self
            .padding(.top, FloatingBarInsets.top)
            .padding(.bottom, FloatingBarInsets.bottom)
            .environment(\.hasFloatingTabBarInset, true)
    }
}
