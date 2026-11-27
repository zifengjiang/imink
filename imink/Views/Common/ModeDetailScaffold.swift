import SwiftUI
import UIKit

/// 对战与打工（单局详情 / 班次详情）共用的模式主题描述。
///
/// 模式差异只通过 `accent`（模式色）、`modeBadge`（模式角标）和 `icon`（模式图标）表达，
/// 页面骨架、卡片圆角、内距、字阶与底部操作区保持完全一致。
struct ModeDetailHeaderConfig {
    let modeBadge: String
    let title: String
    let subtitle: String
    let accent: Color
    let icon: Image
    var resultText: String? = nil
    var resultColor: Color = .appLabel
    var resultSubtext: String? = nil
}

/// 详情页顶部统一指标卡的数据模型（标签在上、等宽数值在下、单位小一号）。
struct ModeDetailMetric: Identifiable {
    let id: String
    let label: String
    let value: String
    var unit: String? = nil
    var valueColor: Color = .appLabel

    init(
        id: String? = nil,
        label: String,
        value: String,
        unit: String? = nil,
        valueColor: Color = .appLabel
    ) {
        self.id = id ?? label
        self.label = label
        self.value = value
        self.unit = unit
        self.valueColor = valueColor
    }
}

/// 对战 / 打工详情页与班次详情页的共享页面骨架（方向 A「街头涂鸦战术板」，4pt 栅格）。
struct ModeDetailScaffold<HeroContent: View, BodyContent: View>: View {
    let header: ModeDetailHeaderConfig
    let metrics: [ModeDetailMetric]
    let shareSummary: String
    var onSaveImage: (() -> Void)? = nil
    @ViewBuilder let heroContent: HeroContent
    @ViewBuilder let bodyContent: BodyContent

    init(
        header: ModeDetailHeaderConfig,
        metrics: [ModeDetailMetric],
        shareSummary: String,
        onSaveImage: (() -> Void)? = nil,
        @ViewBuilder heroContent: () -> HeroContent,
        @ViewBuilder bodyContent: () -> BodyContent
    ) {
        self.header = header
        self.metrics = metrics
        self.shareSummary = shareSummary
        self.onSaveImage = onSaveImage
        self.heroContent = heroContent()
        self.bodyContent = bodyContent()
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                if !metrics.isEmpty {
                    metricsStrip
                }

                bodyContent

                bottomActionBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .clearFloatingBars()
        }
        .scrollIndicators(.hidden)
        .environment(\.hasFloatingTabBarInset, true)
        .fixSafeareaBackground()
        .ignoresSafeArea(edges: .vertical)
    }

    // MARK: - 1. 统一页头卡

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                header.icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 40, height: 40)
                    .background(header.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(header.modeBadge)
                            .font(.appSubCaptionMono)
                            .foregroundStyle(header.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(header.accent.opacity(0.14), in: Capsule())

                        Text(header.subtitle)
                            .font(.appCaptionMono)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Text(header.title)
                        .font(.appTitle)
                        .foregroundStyle(.appLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                if let resultText = header.resultText, !resultText.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(resultText)
                            .font(.appGameSubhead)
                            .foregroundStyle(header.resultColor)
                            .lineLimit(1)

                        if let sub = header.resultSubtext, !sub.isEmpty {
                            Text(sub)
                                .font(.appSubCaptionMono)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(minHeight: 48)

            heroContent
        }
        .padding(12)
        .textureBackground(texture: .bubble, radius: 16)
        .overlay(alignment: .top) {
            Capsule()
                .fill(header.accent)
                .frame(height: 3)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - 2. 统一指标卡条（3~4 列，标签在上、等宽数字在下、单位小一号）

    private var metricsStrip: some View {
        HStack(spacing: 8) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.label)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(metric.value)
                            .font(.appHeadlineMono)
                            .foregroundStyle(metric.valueColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        if let unit = metric.unit, !unit.isEmpty {
                            Text(unit)
                                .font(.appSubCaptionMono)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - 3. 统一底部次要操作区（复制战报 / 系统分享 / 可选保存长图）

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = shareSummary
                Haptics.generateIfEnabled(.light)
                Toast.success("已复制战绩摘要")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                    Text("复制摘要")
                        .font(.appCaption)
                }
                .foregroundStyle(.appLabel)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            ShareLink(item: shareSummary) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text("分享战报")
                        .font(.appCaption)
                }
                .foregroundStyle(header.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(header.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if let onSaveImage {
                Button {
                    Haptics.generateIfEnabled(.medium)
                    onSaveImage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                        Text("存相册")
                            .font(.appCaption)
                    }
                    .foregroundStyle(.appLabel)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

/// 详情页统一小节容器（统一小节标题字号/字重/上下留白 + 可选右侧计数）。
struct ModeDetailSection<Content: View>: View {
    let title: String
    var trailing: String? = nil
    var accent: Color = .accentColor
    @ViewBuilder let content: Content

    init(
        title: String,
        trailing: String? = nil,
        accent: Color = .accentColor,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent)
                    .frame(width: 4, height: 16)

                Text(title)
                    .font(.appHeadline)
                    .foregroundStyle(.appLabel)

                Spacer()

                if let trailing, !trailing.isEmpty {
                    Text(trailing)
                        .font(.appCaptionMono)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)

            content
        }
    }
}

/// 详情页统一内容卡片（4pt 栅格：12pt 圆角、12pt 内距、统一列表卡片底色）。
struct ModeDetailCard<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder let content: Content

    init(padding: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
