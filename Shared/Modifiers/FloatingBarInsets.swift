import SwiftUI
import UIKit

/// 悬浮栏（顶部导航工具栏 + 底部 Liquid Glass 浮动 Tab 栏）统一避让常量与修饰器。
///
/// 设计原则：
/// 1. 实测 iOS 26/27 浮动胶囊 Tab 栏位于距屏幕底边 21pt~83pt 区间（本体高约 62pt，系统 `TabView` 已将容器
///    `safeAreaInsets.bottom` 设为胶囊顶沿高度 `83pt`，内含 Home Indicator 区域，严禁再把 `64pt` 重复叠加到 `34pt` 之上）；
/// 2. 所有页面通过 `.floatingTabBarInset()`（或自动继承自 `.fixSafeareaBackground()`）仅注入 **透明** `Color.clear`
///    呼吸净空（`16pt`），既让滚动过程中的内容自然穿过半透明 Liquid Glass 胶囊背面（消除底部实心灰块“空白占位”），
///    又保证滑到底部时最后一张卡片停在浮动 Tab 栏顶沿上方统一的 `16pt` 呼吸距离处；
/// 3. 通过 `@Environment(\.hasFloatingTabBarInset)` 防止父子容器嵌套时重复叠加底部留白。
enum FloatingBarInsets {
    /// 浮动胶囊 Tab 栏实测本体高度（21pt ~ 83pt）
    static let tabBarHeight: CGFloat = 62

    /// 卡片底部与浮动 Tab 栏顶沿之间的统一呼吸间距（4pt 栅格，与水平边距 16pt 对齐）
    static let breathingSpacing: CGFloat = 16

    /// 浮动胶囊 Tab 栏顶沿距屏幕物理底边的高度（iOS TabView 标准底部安全区 83pt = 34pt + 49pt）
    static var tabBarTopFromScreenBottom: CGFloat {
        max(safeArea.bottom + 49, 83)
    }

    /// 顶部：安全区 + 悬浮导航工具栏高度（用于完全 ignoresSafeArea 的全屏滚动容器）
    static var top: CGFloat { safeArea.top + 56 }

    /// 底部：浮动 Tab 栏顶沿高度 + 统一呼吸间距（用于完全 ignoresSafeArea 的全屏滚动容器，不重复计算 safeArea.bottom）
    static var bottom: CGFloat { tabBarTopFromScreenBottom + breathingSpacing }

    static var safeArea: UIEdgeInsets {
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
/// - 若系统 `TabView` 已注入胶囊顶沿高度（`~83pt`），仅补充 `16pt` 透明呼吸净空（总计距屏幕底边 `99pt`）；
/// - 若因 `.tabBarMinimizeBehavior(.onScrollDown)` 或全屏容器导致 `containerBottomInset < 83pt`，自动补齐差额至 `99pt`；
/// - 严禁使用不透明背景色填充 `safeAreaInset`，否则会在未滑到底部时在 Tab 栏上方形成遮挡内容的空白色带。
struct FloatingTabBarInsetModifier: ViewModifier {
    @Environment(\.hasFloatingTabBarInset) private var hasApplied
    @State private var containerBottomInset: CGFloat = FloatingBarInsets.tabBarTopFromScreenBottom

    private var extraBottomInset: CGFloat {
        let targetFromScreenBottom = FloatingBarInsets.bottom
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
