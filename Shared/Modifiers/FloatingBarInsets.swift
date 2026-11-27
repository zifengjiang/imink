import SwiftUI
import UIKit

/// 悬浮栏（顶部导航工具栏 + 底部 Liquid Glass 浮动 Tab 栏）统一避让常量与修饰器。
///
/// 设计原则：
/// 1. 实测 iOS 26/27 浮动胶囊 Tab 栏本体高度约 64pt，叠加底部 Home Indicator 安全区与 20pt 呼吸间距；
/// 2. 所有页面通过 `.floatingTabBarInset()`（或自动继承自 `.fixSafeareaBackground()`）统一让出底部空间，
///    严禁在各业务页面散落硬编码魔法数字；
/// 3. 通过 `@Environment(\.hasFloatingTabBarInset)` 防止父子容器嵌套时重复叠加底部留白。
enum FloatingBarInsets {
    /// 浮动胶囊 Tab 栏实测高度
    static let tabBarHeight: CGFloat = 64

    /// 卡片底部与浮动 Tab 栏顶沿之间的呼吸间距（4pt 栅格）
    static let breathingSpacing: CGFloat = 20

    /// 相对底部安全区之上的额外净空高度（Tab 栏高度 + 呼吸间距 = 84pt）
    static let tabBarClearance: CGFloat = tabBarHeight + breathingSpacing

    /// 顶部：安全区 + 悬浮导航工具栏高度（用于完全 ignoresSafeArea 的全屏滚动容器）
    static var top: CGFloat { safeArea.top + 56 }

    /// 底部：安全区 + 浮动 Tab 栏净空高度（用于完全 ignoresSafeArea 的全屏滚动容器）
    static var bottom: CGFloat { safeArea.bottom + tabBarClearance }

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

/// 为滚动容器（`ScrollView` / `List`）注入统一的浮动 Tab 栏底部 `safeAreaInset`。
///
/// 自动读取当前容器已有的 `safeAreaInsets.bottom`：
/// - 若系统仅注入了 Home Indicator（34pt），补足 `84pt`（总计 `118pt`）；
/// - 若系统已注入传统 TabBar 高度（~83pt），仅补差值与呼吸间距，避免双重留白。
struct FloatingTabBarInsetModifier: ViewModifier {
    @Environment(\.hasFloatingTabBarInset) private var hasApplied
    @State private var containerBottomInset: CGFloat = FloatingBarInsets.safeArea.bottom

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
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color("ListBackgroundColor").opacity(0),
                                Color("ListBackgroundColor")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: FloatingBarInsets.breathingSpacing)

                        Color("ListBackgroundColor")
                            .frame(height: max(0, extraBottomInset - FloatingBarInsets.breathingSpacing))
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        Color("ListBackgroundColor")
                            .padding(.top, FloatingBarInsets.breathingSpacing)
                            .ignoresSafeArea(edges: .bottom)
                    )
                    .allowsHitTesting(false)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.bottom
                } action: { outerBottom in
                    if abs(outerBottom - containerBottomInset) > 0.5 {
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
