import SwiftUI
import UIKit

/// 游戏字体的行高收口。
///
/// ## 为什么要单独做（实测，不靠猜）
///
/// 用 CoreText 直接量 `Shared/Utils` 下的字体文件（13pt，`ascent + descent + leading` / `size`）：
///
/// | 字体 | PostScript | lineHeight / size | ascent / size | capHeight / size |
/// | --- | --- | --- | --- | --- |
/// | 简体中文（默认） | `DFPZongYiW7` | **1.000** | 0.859 | 0.762 |
/// | 繁体中文 | `DFP222` | 0.855 | 0.687 | 0.751 |
/// | 日文 | `KurokaneStd-EB` | 1.600 | 0.704 | 0.769 |
/// | 韩文 | `KoreanERIN-M` | 1.166 | 0.806 | 0.769 |
/// | 口号 / 展示 | `Splatfont1v1.008-Regular` | **2.000** | 1.380 | 0.935 |
///
/// 对照 SF Pro 的 1.19×，结论和最初的假设相反：
/// - 中文默认字体的自然行高只有 **1.0×**，比 SF Pro 还紧，所以全站换成游戏字体后**行距变小、行与行贴住**
///   （字面本身又更大：capHeight 0.762 vs SF Pro 约 0.70，视觉密度更高）；
/// - 只有 Splatfont 1（口号）是 2.0×，会把单行文字的行盒撑到两倍高。
///
/// 因此这里给出两个工具：
/// 1. `.appLineHeight(size:)` —— SwiftUI 侧，把自然行高**补**到目标行高（`size × 1.2`，≥17pt 用 `size × 1.15`）；
///    走 `.lineSpacing`，只作用于多行文本的行间，不会抬高单行文字的行盒，所以对列表行高零影响。
/// 2. `GameText` —— `UILabel` 支撑的精确行高文本（`minimumLineHeight == maximumLineHeight == size × ratio`），
///    用于 SwiftUI 无法**压缩**行高的场景（Splatfont 1 的 2.0×）。
enum AppLineMetrics {
    /// 实测的 `lineHeight / size`。
    static func measuredRatio(for font: Font.CustomFont) -> CGFloat {
        switch font {
        case .zhHans: return 1.000
        case .zhHant: return 0.855
        case .ja: return 1.600
        case .ko: return 1.166
        case .splatoon1: return 2.000
        }
    }

    /// 当前语种实际使用的游戏字体行高比。
    static var currentRatio: CGFloat {
        measuredRatio(for: Font.preferredGameCustomFont())
    }

    /// 目标行高比：正文 / 数值 1.2×，17pt 及以上的标题 1.15×。
    static func targetRatio(for size: CGFloat) -> CGFloat {
        size >= 17 ? 1.15 : 1.2
    }

    /// 需要补的行间空白（中文 1.0× → 15pt 补 3pt；日文 1.6× 则为 0，不能为负）。
    static func extraSpacing(for size: CGFloat) -> CGFloat {
        max(0, size * (targetRatio(for: size) - currentRatio))
    }

    /// 需要压缩的量（Splatfont 1 的 2.0× → 15pt 需要压 12pt），只有 `GameText` 能真正做到。
    static func overSpacing(for size: CGFloat) -> CGFloat {
        max(0, size * (currentRatio - targetRatio(for: size)))
    }

    /// 目标行高绝对值。
    static func lineHeight(for size: CGFloat, ratio: CGFloat? = nil) -> CGFloat {
        size * (ratio ?? targetRatio(for: size))
    }
}

extension View {
    /// 把子视图里多行文本的行高补到 `size × 1.2`（≥17pt 为 `× 1.15`）。
    ///
    /// - `lineSpacing` 只增加行与行之间的空白，单行文本与列表行高完全不受影响；
    /// - 会向下继承给 `Text`（与 `.font` 一样走环境），所以页面根加一次即可，局部可以再覆盖。
    func appLineHeight(_ size: CGFloat = AppFontScale.body) -> some View {
        self.lineSpacing(AppLineMetrics.extraSpacing(for: size))
    }
}

/// `UILabel` 支撑的精确行高文本。
///
/// 用途：SwiftUI `Text` / `.lineSpacing` 只能**增大**行距，遇到 Splatfont 1 这种 2.0× 自然行高的字体
/// 会把单行文字的行盒撑高一倍，只能靠 `NSMutableParagraphStyle.minimumLineHeight = maximumLineHeight`
/// 压回 `size × 1.2`。需要压行高的地方（口号、列表卡里的「Clear!! / LOSE…」）用它替换 `Text`。
struct GameText: UIViewRepresentable {
    let text: String
    var size: CGFloat = AppFontScale.body
    var ratio: CGFloat? = nil
    var weight: UIFont.Weight = .regular
    var color: UIColor = .label
    var lineLimit: Int = 1
    var alignment: NSTextAlignment = .left

    init(
        _ text: String,
        size: CGFloat = AppFontScale.body,
        ratio: CGFloat? = nil,
        weight: UIFont.Weight = .regular,
        color: UIColor = .label,
        lineLimit: Int = 1,
        alignment: NSTextAlignment = .left
    ) {
        self.text = text
        self.size = size
        self.ratio = ratio
        self.weight = weight
        self.color = color
        self.lineLimit = lineLimit
        self.alignment = alignment
    }

    func makeUILabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = lineLimit
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func makeUIView(context: Context) -> UILabel {
        makeUILabel()
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let lineHeight = AppLineMetrics.lineHeight(for: size, ratio: ratio)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        paragraph.alignment = alignment
        label.numberOfLines = lineLimit
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: Font.gameUIFont(size: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
        label.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView label: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? .greatestFiniteMagnitude
        let fitted = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: proposal.width ?? fitted.width, height: ceil(fitted.height))
    }
}
