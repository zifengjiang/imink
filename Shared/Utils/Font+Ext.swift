import Foundation
import SwiftUI
import UIKit

/// 全应用统一字阶（方向 A「街头涂鸦战术板」）。
///
/// 规则：
/// 1. 最小字号严格不低于 `11pt`（彻底杜绝 7pt~10pt 糊字）。
/// 2. 17pt 及以上（`display` 28pt、`title` 20pt、`headline` 17pt、大号战绩指标）与短促战绩印章使用按语种路由的游戏展示字体，并通过 `relativeTo:` 支持系统 Dynamic Type 缩放。
/// 3. 15pt 及以下正文、辅助说明与常规数值同样使用按语种路由的游戏字体（`appBody` / `appBodyMono` / `appMono` / `appCaption` / `appCaptionMono` / `appSubCaptionMono`），尺寸基准与 `.relativeTo:` 字阶不变，数值强制 `.monospacedDigit()`。
/// 4. 全站不再保留 SF Pro 的「正文/小字」层级：字形不混用，避免标题与正文突兀；小尺寸仍走同一套字体，靠字号与字重拉开层级。
enum AppFontScale {
    static let display: CGFloat = 28
    static let title: CGFloat = 20
    static let headline: CGFloat = 17
    static let body: CGFloat = 15
    static let mono: CGFloat = 13
    static let caption: CGFloat = 12
    static let minimum: CGFloat = 11
}

extension Font {
    enum CustomFont: String, CaseIterable {
        case zhHans = "DFPZongYiW7-GB"
        case splatoon1 = "Splatfont 1 v1.008"
        case zhHant = "DFP222"
        case ko = "AsiaKERIN-M"
        case ja = "FOT-Kurokane Std EB"
    }

    /// 进程内一次性缓存系统已注册 PostScript 字体名集合，避免列表每行渲染时反复创建 `UIFont` 探测。
    private static let availableFontNames: Set<String> = Set(
        UIFont.familyNames.flatMap { UIFont.fontNames(forFamilyName: $0) }
    )

    /// 家族名 → 首个 PostScript 名（进程内缓存一次）。
    private static let postScriptNameByFamily: [String: String] = {
        var map: [String: String] = [:]
        for family in UIFont.familyNames {
            if let ps = UIFont.fontNames(forFamilyName: family).first {
                map[family] = ps
            }
        }
        return map
    }()

    /// 解析可用的 PostScript 名：`rawValue` 本身就是 PostScript 名则直接返回，否则按家族名查表。
    static func resolvedName(for font: CustomFont) -> String? {
        if availableFontNames.contains(font.rawValue) {
            return font.rawValue
        }
        if let ps = postScriptNameByFamily[font.rawValue], availableFontNames.contains(ps) {
            return ps
        }
        return UIFont.fontNames(forFamilyName: font.rawValue).first
    }

    /// 进程内缓存当前系统首选语言对应的游戏展示字体，消除每行列表重复读取 `Locale` 与字符串扫描开销。
    private static let cachedPreferredGameFont: CustomFont = resolvePreferredGameCustomFont()

    // MARK: - 语义化字阶入口（全部接入 Dynamic Type）

    /// 28pt 基准游戏展示体（随 `.title` 动态缩放）。
    static var appDisplay: Font {
        gameDisplayFont(size: AppFontScale.display, relativeTo: .title)
    }

    /// 20pt 基准游戏标题体（随 `.title3` 动态缩放）。
    static var appTitle: Font {
        gameDisplayFont(size: AppFontScale.title, relativeTo: .title3)
    }

    /// 大号战绩展示数字（>= 20pt，默认 24pt，随 `.title2` 动态缩放）。
    static func appGameMetric(size: CGFloat = 24) -> Font {
        gameDisplayFont(size: max(size, AppFontScale.title), relativeTo: .title2).monospacedDigit()
    }

    /// 15pt 基准游戏徽章体（仅用于 `WIN! / LOSE... / Clear!! / VICTORY` 等短促战绩口号，随 `.subheadline` 动态缩放）。
    static var appGameSubhead: Font {
        gameDisplayFont(size: AppFontScale.body, relativeTo: .subheadline)
    }

    /// 17pt 基准游戏标题体（卡片标题 / 分组主标签，随 `.headline` 动态缩放）。
    static var appHeadline: Font {
        gameDisplayFont(size: AppFontScale.headline, relativeTo: .headline)
    }

    /// 17pt 基准游戏标题等宽数值体（汇总指标大数字，随 `.headline` 动态缩放）。
    static var appHeadlineMono: Font {
        gameDisplayFont(size: AppFontScale.headline, relativeTo: .headline).monospacedDigit()
    }

    // MARK: - 正文 / 辅助字阶入口（全站游戏字体：不再使用 SF Pro，避免与标题字形突兀）

    /// 15pt 基准游戏字体（正文 / 玩家昵称 / 列表主文案，随 `.subheadline` 动态缩放）。
    static var appBody: Font {
        gameDisplayFont(size: AppFontScale.body, relativeTo: .subheadline)
    }

    /// 15pt 基准游戏字体等宽数值（涂地点数 / 关键战绩值，随 `.subheadline` 动态缩放）。
    static var appBodyMono: Font {
        gameDisplayFont(size: AppFontScale.body, relativeTo: .subheadline).monospacedDigit()
    }

    /// 13pt 基准游戏字体等宽数值（列表行/详情行常规数值、KDA、胜率，随 `.footnote` 动态缩放）。
    static var appMono: Font {
        gameDisplayFont(size: AppFontScale.mono, relativeTo: .footnote).monospacedDigit()
    }

    /// 12pt 基准游戏字体（辅助说明 / 地图名 / 模式名，随 `.caption` 动态缩放）。
    static var appCaption: Font {
        gameDisplayFont(size: AppFontScale.caption, relativeTo: .caption)
    }

    /// 12pt 基准游戏字体等宽数值（时间戳 / 次级计数 / 危险度，随 `.caption` 动态缩放）。
    static var appCaptionMono: Font {
        gameDisplayFont(size: AppFontScale.caption, relativeTo: .caption).monospacedDigit()
    }

    /// 11pt 基准游戏字体等宽数值（全局字号下限，随 `.caption2` 动态缩放）。
    static var appSubCaptionMono: Font {
        gameDisplayFont(size: AppFontScale.minimum, relativeTo: .caption2).monospacedDigit()
    }

    // MARK: - 小号游戏字体语义别名（表达式可读性 / 卡片语境用，全部指向上面的同一实现）

    static var appGameBody: Font { appBody }
    static var appGameBodyMono: Font { appBodyMono }
    static var appGameMono: Font { appMono }
    static var appGameCaption: Font { appCaption }
    static var appGameCaptionMono: Font { appCaptionMono }
    static var appGameSubCaptionMono: Font { appSubCaptionMono }

    // MARK: - 语种路由与底层加载

    /// 返回当前系统首选语言对应的游戏展示字体（命中静态缓存，O(1)）。
    static func preferredGameCustomFont() -> CustomFont {
        cachedPreferredGameFont
    }

    /// 解析指定首选语言列表对应的游戏展示字体（遵循 RFC 5646：先判 `script`，仅在 `script` 缺失时回退到 `region`）。
    static func resolvePreferredGameCustomFont(
        preferredLanguages: [String] = Locale.preferredLanguages,
        fallbackLocale: Locale = .current
    ) -> CustomFont {
        let identifier = preferredLanguages.first ?? fallbackLocale.identifier
        let locale = Locale(identifier: identifier)
        let languageCode = locale.language.languageCode?.identifier ?? ""
        let scriptCode = locale.language.script?.identifier ?? ""
        let regionCode = locale.region?.identifier ?? ""

        switch languageCode {
        case "zh":
            if scriptCode == "Hant" {
                return .zhHant
            }
            if scriptCode == "Hans" {
                return .zhHans
            }
            // 仅当语言标识符未显式携带 Hans/Hant 脚本标签（如 zh-HK / zh-TW / zh-MO）时才参考地区码
            if ["TW", "HK", "MO"].contains(regionCode) {
                return .zhHant
            }
            return .zhHans
        case "ja":
            return .ja
        case "ko":
            return .ko
        default:
            return .splatoon1
        }
    }

    static func customFont(
        _ font: CustomFont,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle? = nil
    ) -> Font {
        let clampedSize = max(size, AppFontScale.minimum)
        let resolvedStyle = textStyle ?? semanticTextStyle(for: clampedSize)

        if let postScriptName = resolvedName(for: font) {
            return .custom(postScriptName, size: clampedSize, relativeTo: resolvedStyle)
        }
        if font == .zhHant, let fallbackPostScriptName = resolvedName(for: .zhHans) {
            return .custom(fallbackPostScriptName, size: clampedSize, relativeTo: resolvedStyle)
        }
        return scaledSystemFont(size: clampedSize, weight: .bold, relativeTo: resolvedStyle)
    }

    static func gameDisplayFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle? = nil
    ) -> Font {
        let clampedSize = max(size, AppFontScale.minimum)
        return customFont(cachedPreferredGameFont, size: clampedSize, relativeTo: textStyle)
    }

    // MARK: - UIKit 侧游戏字体（`UINavigationBar` / `UITabBarItem` 只接受 `UIFont`）

    /// 返回 `UIFont` 形态的游戏字体，供 `UIAppearance` 使用（导航栏标题、标签栏标题）。
    ///
    /// 说明：
    /// - 与 SwiftUI 侧共用同一套语种路由（`.zhHant` 缺失时回退 `.zhHans`）；
    /// - 游戏字体只有单一字重，`weight` 通过 descriptor 尝试调整，若被系统换族（即真的回退成
    ///   系统字体）则丢弃该次调整、保留游戏字体，避免字形意外变回 SF Pro；
    /// - 唯一允许的 SF Pro 兜底：字体文件未注册（资源缺失 / 越狱裁剪）时退回系统字体，
    ///   否则 `UIAppearance` 里拿不到字体会让整个导航栏、标签栏变成空白。
    static func gameUIFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let clampedSize = max(size, AppFontScale.minimum)
        var postScriptName = resolvedName(for: cachedPreferredGameFont)
        if postScriptName == nil, cachedPreferredGameFont == .zhHant {
            postScriptName = resolvedName(for: .zhHans)
        }
        guard let postScriptName, let base = UIFont(name: postScriptName, size: clampedSize) else {
            return .systemFont(ofSize: clampedSize, weight: weight)
        }
        guard weight != .regular else { return base }
        let descriptor = base.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        let weighted = UIFont(descriptor: descriptor, size: clampedSize)
        return weighted.familyName == base.familyName ? weighted : base
    }

    // MARK: - 兼容收敛入口（强制 >= 11pt、支持 Dynamic Type，小字同样走游戏字体）

    static func splatoonFont1(size: CGFloat) -> Font {
        let clampedSize = max(size, AppFontScale.minimum)
        let style = semanticTextStyle(for: clampedSize)
        guard clampedSize >= 14 else {
            return gameDisplayFont(size: clampedSize, relativeTo: style).monospacedDigit()
        }
        return customFont(.splatoon1, size: clampedSize, relativeTo: style)
    }

    static func splatoonFont(size: CGFloat) -> Font {
        let clampedSize = max(size, AppFontScale.minimum)
        let style = semanticTextStyle(for: clampedSize)
        return gameDisplayFont(size: clampedSize, relativeTo: style)
    }

    private static func semanticTextStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 26...:
            return .title
        case 22..<26:
            return .title2
        case 19..<22:
            return .title3
        case 16.5..<19:
            return .headline
        case 14..<16.5:
            return .subheadline
        case 12.5..<14:
            return .footnote
        case 11.5..<12.5:
            return .caption
        default:
            return .caption2
        }
    }

    private static func uiTextStyle(for style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }

    private static func scaledSystemFont(
        size: CGFloat,
        weight: UIFont.Weight,
        relativeTo style: Font.TextStyle
    ) -> Font {
        let baseSize = max(size, AppFontScale.minimum)
        let metrics = UIFontMetrics(forTextStyle: uiTextStyle(for: style))
        let scaledSize = max(metrics.scaledValue(for: baseSize), AppFontScale.minimum)
        return Font(UIFont.systemFont(ofSize: scaledSize, weight: weight))
    }

    // MARK: - 游戏铭牌等比画布专用（铭牌按 284pt 基准画布等比缩放，不随外部字阶变形）

    static func nameplateCanvasFont(size: CGFloat) -> Font {
        if let postScriptName = resolvedName(for: cachedPreferredGameFont),
           let uiFont = UIFont(name: postScriptName, size: size) {
            return Font(uiFont)
        }
        return .system(size: size, weight: .semibold)
    }

    static func nameplateCanvasTitleFont(size: CGFloat) -> Font {
        if let postScriptName = resolvedName(for: .splatoon1),
           let uiFont = UIFont(name: postScriptName, size: size) {
            return Font(uiFont)
        }
        return .system(size: size, weight: .bold)
    }
}
