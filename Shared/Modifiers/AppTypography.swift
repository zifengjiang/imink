import SwiftUI
import UIKit

/// 全站排版收口：把系统自绘的导航栏 / 标签栏文字，以及页面根的默认字体统一成游戏字体。
///
/// 设计原则：
/// 1. 页面根用 `.appGameTypography()` 注入默认字体，让**没有显式 `.font(...)` 的 `Text`** 继承游戏字体；
///    局部仍然可以写 `appTitle` / `appBody` / `appCaption` 等语义字阶，显式字阶不会被压平。
/// 2. 导航栏标题与返回按钮由 UIKit 绘制，只能走 `UIAppearance`，字体统一取
///    `Font.gameUIFont(size:)`（唯一的 SF Pro 兜底写在 `gameUIFont` 里）。
/// 3. 底部浮动胶囊标签栏的标题**不可自定义**：iOS 26 忽略 `UITabBarItem` /
///    `UITabBarAppearance` 的 title attributes（也忽略 `Tab` 自定义 label 里的 `.font`），
///    而改它们还会把 app 的 accent color 重置成系统蓝。所以这里只动导航栏，标签栏保持系统字体。
/// 4. 只改字体，不改背景 / 层级 / block 配置，保持 iOS 26 Liquid Glass 的原有观感。
enum AppTypography {
    /// 导航栏标题（inline）字号
    static let navigationTitleSize: CGFloat = 17
    /// 导航栏大标题字号
    static let navigationLargeTitleSize: CGFloat = 34

    /// 在 `iminkApp.init()` 里调用一次。
    static func install() {
        installNavigationBar()
    }

    private static func installNavigationBar() {
        let titleFont = Font.gameUIFont(size: navigationTitleSize)
        let largeTitleFont = Font.gameUIFont(size: navigationLargeTitleSize)
        let backFont = Font.gameUIFont(size: navigationTitleSize)

        let proxy = UINavigationBar.appearance()
        // 直接写在 appearance proxy 上：不新建 `UINavigationBarAppearance`，
        // 避免把 iOS 26 的默认玻璃背景替换成 `UINavigationBarAppearance()` 的纯透明/纯色背景。
        proxy.titleTextAttributes = [.font: titleFont]
        proxy.largeTitleTextAttributes = [.font: largeTitleFont]

        // 若系统已为某些场景提供了 appearance 对象，则同步字体；背景（含 blur / 透明度）原样保留。
        for appearance in appearanceObjects(of: proxy) {
            appearance.titleTextAttributes = [.font: titleFont]
            appearance.largeTitleTextAttributes = [.font: largeTitleFont]
            appearance.backButtonAppearance.normal.titleTextAttributes = [.font: backFont]
        }
    }

    /// 读取当前已生效的 `UINavigationBarAppearance`（没有配置过就返回空数组，交给 proxy 属性生效）。
    private static func appearanceObjects(of proxy: UINavigationBar) -> [UINavigationBarAppearance] {
        [proxy.standardAppearance, proxy.scrollEdgeAppearance, proxy.compactAppearance].compactMap { $0 }
    }
}

extension View {
    /// 页面根的默认字体：没有显式 `.font(...)` 的文本继承游戏字体。
    ///
    /// 只应加在**页面根**（Tab 根、`NavigationStack` / `.sheet` / `.fullScreenCover` 的内容根），
    /// 不要加在 `ScrollView` 内部的局部容器上 —— 那会把局部已有的语义字阶压平。
    func appGameTypography() -> some View {
        self.font(.appBody)
    }
}
