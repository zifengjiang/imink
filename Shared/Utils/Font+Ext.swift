import Foundation
import SwiftUI
import UIKit

/// 全应用统一字阶（方向 A「街头涂鸦战术板」）。
///
/// 规则：
/// 1. 最小字号严格不低于 `11pt`（彻底杜绝 7pt~10pt 糊字）。
/// 2. 标题、胜负印章与核心战绩大字允许使用按语种路由的游戏展示字体。
/// 3. 正文、辅助说明与所有常规数值统一使用 SF Pro，且数值强制启用 `.monospacedDigit()`。
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
    enum CustomFont: String {
        case zhHans = "DFPZongYiW7-GB"
        case splatoon1 = "Splatfont 1 v1.008"
        case zhHant = "DFP222"
        case ko = "AsiaKERIN-M"
        case ja = "FOT-Kurokane Std EB"
    }

    // MARK: - 语义化字阶入口

    /// 28pt 游戏展示体（大号结算词 / 详情页主印章）。
    static var appDisplay: Font {
        gameDisplayFont(size: AppFontScale.display)
    }

    /// 20pt 游戏标题体（模块大标题 / 核心头部标题）。
    static var appTitle: Font {
        gameDisplayFont(size: AppFontScale.title)
    }

    /// 大号战绩展示数字（>= 20pt，默认 24pt，使用对应语种游戏展示体）。
    static func appGameMetric(size: CGFloat = 24) -> Font {
        gameDisplayFont(size: max(size, AppFontScale.title))
    }

    /// 15pt 游戏徽章体（仅用于 `WIN! / LOSE... / Clear!! / VICTORY` 等短促战绩口号）。
    static var appGameSubhead: Font {
        gameDisplayFont(size: AppFontScale.body)
    }

    /// 17pt SF Pro Semibold（卡片副标题 / 分组主标签）。
    static var appHeadline: Font {
        .system(size: AppFontScale.headline, weight: .semibold)
    }

    /// 17pt SF Pro Semibold 等宽数值（汇总指标大数字）。
    static var appHeadlineMono: Font {
        .system(size: AppFontScale.headline, weight: .semibold).monospacedDigit()
    }

    /// 15pt SF Pro Medium（正文 / 玩家昵称 / 列表主文案）。
    static var appBody: Font {
        .system(size: AppFontScale.body, weight: .medium)
    }

    /// 15pt SF Pro Semibold 等宽数值（涂地点数 / 关键战绩值）。
    static var appBodyMono: Font {
        .system(size: AppFontScale.body, weight: .semibold).monospacedDigit()
    }

    /// 13pt SF Pro Semibold 等宽数值（列表行/详情行常规数值、KDA、胜率）。
    static var appMono: Font {
        .system(size: AppFontScale.mono, weight: .semibold).monospacedDigit()
    }

    /// 12pt SF Pro Medium（辅助说明 / 地图名 / 模式名）。
    static var appCaption: Font {
        .system(size: AppFontScale.caption, weight: .medium)
    }

    /// 12pt SF Pro Medium 等宽数值（时间戳 / 次级计数 / 危险度）。
    static var appCaptionMono: Font {
        .system(size: AppFontScale.caption, weight: .medium).monospacedDigit()
    }

    /// 11pt SF Pro Medium 等宽数值（全局字号下限，仅用于括号内助攻等紧凑角标）。
    static var appSubCaptionMono: Font {
        .system(size: AppFontScale.minimum, weight: .medium).monospacedDigit()
    }

    // MARK: - 语种路由与底层加载

    /// 根据系统首选语言（不依赖美区 Region）选择对应的游戏展示字体。
    static func preferredGameCustomFont(
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
            if scriptCode == "Hant"
                || ["TW", "HK", "MO"].contains(regionCode)
                || identifier.localizedCaseInsensitiveContains("Hant") {
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

    static func customFont(_ font: CustomFont, size: CGFloat) -> Font {
        let clampedSize = max(size, AppFontScale.minimum)
        if let uiFont = UIFont(name: font.rawValue, size: clampedSize) {
            return Font(uiFont)
        }
        if font == .zhHant, let fallback = UIFont(name: CustomFont.zhHans.rawValue, size: clampedSize) {
            return Font(fallback)
        }
        return .system(size: clampedSize, weight: .bold)
    }

    static func gameDisplayFont(size: CGFloat) -> Font {
        let clampedSize = max(size, AppFontScale.minimum)
        return customFont(preferredGameCustomFont(), size: clampedSize)
    }

    // MARK: - 兼容收敛入口（强制 >= 11pt 且小字自动走 SF Pro 等宽）

    static func splatoonFont1(size: CGFloat) -> Font {
        let clampedSize = max(size, AppFontScale.minimum)
        guard clampedSize >= 14 else {
            return .system(size: clampedSize, weight: .semibold).monospacedDigit()
        }
        return customFont(.splatoon1, size: clampedSize)
    }

    static func splatoonFont(size: CGFloat) -> Font {
        let clampedSize = max(size, AppFontScale.minimum)
        if clampedSize >= AppFontScale.title {
            return gameDisplayFont(size: clampedSize)
        }
        let weight: Font.Weight = clampedSize >= AppFontScale.body ? .semibold : .medium
        return .system(size: clampedSize, weight: weight).monospacedDigit()
    }

    // MARK: - 游戏铭牌等比画布专用（铭牌按 284pt 基准画布等比缩放，不作 UI 文本字阶截断）

    static func nameplateCanvasFont(size: CGFloat) -> Font {
        let resolvedFont = preferredGameCustomFont()
        if let uiFont = UIFont(name: resolvedFont.rawValue, size: size) {
            return Font(uiFont)
        }
        return .system(size: size, weight: .semibold)
    }

    static func nameplateCanvasTitleFont(size: CGFloat) -> Font {
        if let uiFont = UIFont(name: CustomFont.splatoon1.rawValue, size: size) {
            return Font(uiFont)
        }
        return .system(size: size, weight: .bold)
    }
}
