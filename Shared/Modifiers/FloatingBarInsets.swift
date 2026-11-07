import SwiftUI
import UIKit

/// 悬浮栏（顶部工具栏 + 底部 Tab 栏）遮挡内容时的留白计算。
///
/// 不依赖 `contentMargins` / `scrollClipDisabled` 这类随系统版本变化的 inset 语义：
/// 滚动视图直接铺满全屏，内容自己用 padding 让开栏位。
enum FloatingBarInsets {
    /// 顶部：安全区 + 悬浮工具栏高度
    static var top: CGFloat { safeArea.top + 56 }

    /// 底部：安全区（含悬浮 Tab 栏）+ 呼吸间距
    static var bottom: CGFloat { safeArea.bottom + 16 }

    private static var safeArea: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    }
}

/// 按"系统已经给了多少 inset"补齐差额。
///
/// 不同 iOS 版本 / 不同容器层级下，系统注入的安全区不一致：
/// 有时内容已经被 inset 了安全区，有时没有。这里读取实际值，只补差额，
/// 避免出现"栏不透明 + 上方空一大块"的双重偏移。
struct FloatingBarPadding: ViewModifier {
    let currentInsets: EdgeInsets

    func body(content: Content) -> some View {
        content
            .padding(.top, max(0, FloatingBarInsets.top - currentInsets.top))
            .padding(.bottom, max(0, FloatingBarInsets.bottom - currentInsets.bottom))
    }
}

extension View {
    /// 滚动内容让开顶部悬浮栏与底部 Tab 栏（差额补齐版）。
    ///
    /// 适用于「容器已被系统 inset」的场景：只补差值，不会出现双重偏移。
    func clearFloatingBars(currentInsets: EdgeInsets) -> some View {
        modifier(FloatingBarPadding(currentInsets: currentInsets))
    }

    /// 滚动内容让开栏位（全量版）。
    ///
    /// 适用于「内容已经 ignoreSafeArea 铺满全屏」的场景，直接按栏高留白。
    func clearFloatingBars() -> some View {
        self
            .padding(.top, FloatingBarInsets.top)
            .padding(.bottom, FloatingBarInsets.bottom)
    }
}
