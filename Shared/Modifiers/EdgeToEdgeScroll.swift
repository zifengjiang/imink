import SwiftUI
import UIKit

/// 屏幕边缘相关的尺寸。
///
/// 全屏铺满的滚动内容需要自己留出顶部导航栏 / 底部悬浮 Tab 栏的位置，
/// 这些数值取自当前窗口的安全区，避免在代码里散落各种「魔法数字」。
enum ScreenEdgeMetrics {
    /// 顶部内容留白：安全区（状态栏 / 灵动岛）+ 悬浮导航栏高度。
    static var topContentInset: CGFloat { safeArea.top + navigationBarHeight }

    /// 底部内容留白：安全区（含悬浮 Tab 栏）+ 一点呼吸间距。
    static var bottomContentInset: CGFloat { safeArea.bottom + 16 }

    /// 悬浮导航栏（工具栏）大致占用的高度。
    private static let navigationBarHeight: CGFloat = 56

    private static var safeArea: UIEdgeInsets {
        let insets = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets

        // 兜底：取不到窗口时按无边框设备的常见值处理
        return insets ?? UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    }
}

extension View {
    /// 让滚动内容铺到屏幕上下边缘（顶部与底部的玻璃栏可以透出内容），
    /// 同时用内容内边距保证内容不被栏遮挡、可以完整滚动出来。
    func edgeToEdgeScrollContent() -> some View {
        self
            .contentMargins(.top, ScreenEdgeMetrics.topContentInset, for: .scrollContent)
            .contentMargins(.bottom, ScreenEdgeMetrics.bottomContentInset, for: .scrollContent)
    }
}
