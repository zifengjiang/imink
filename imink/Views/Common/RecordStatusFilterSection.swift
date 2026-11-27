import SwiftUI
import SplatDatabase

/// 筛选 Sheet 统一的 4pt 栅格与深浅色语义辅助（对齐 `MePage` 与 `ModeDetailScaffold`）。
enum FilterSheetLayout {
    static let sectionSpacing: CGFloat = 16
    static let horizontalPadding: CGFloat = 16
    static let cardPadding: CGFloat = 12
    static let itemCornerRadius: CGFloat = 10
    static let innerCornerRadius: CGFloat = 8

    /// 顶部概览卡几何常量：整卡高度只由常量决定（12 * 2 + 40 + 10 + 26 = 100pt）。
    static let bannerHeaderHeight: CGFloat = 40
    static let bannerRowSpacing: CGFloat = 10
    static let bannerTagRowHeight: CGFloat = 26
    static let bannerTagChipHeight: CGFloat = 22
    static let summaryBannerHeight: CGFloat =
        cardPadding * 2 + bannerHeaderHeight + bannerRowSpacing + bannerTagRowHeight

    /// 实心 `Color.accentColor` 上的高对比前景色：
    /// 浅色模式 `AccentColor` 为深紫 `#5639D6` 用白字；深色模式为荧光黄绿 `#DCE149` 用深墨黑字。
    static func onAccent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.07, green: 0.08, blue: 0.10) : .white
    }

    /// 卡片内未选中子项底色（与 `Color.listItemBackground` 拉开清晰层次）。
    static func unselectedFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.listBackground
    }
}

/// 筛选页顶部气泡贴纸概览卡（复用 `ModeDetailScaffold` 的 `.bubble` 贴纸纹理，整卡高度锁死为 `FilterSheetLayout.summaryBannerHeight`）。
struct FilterSummaryBanner: View {
    let modeBadge: String
    let title: String
    let accent: Color
    let icon: Image
    let activeTags: [String]

    private static let badgePillHeight: CGFloat = 18
    private static let titleLineHeight: CGFloat = 19
    private static let headerTextSpacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: FilterSheetLayout.bannerRowSpacing) {
            HStack(alignment: .center, spacing: 12) {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .frame(
                        width: FilterSheetLayout.bannerHeaderHeight,
                        height: FilterSheetLayout.bannerHeaderHeight
                    )
                    .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: Self.headerTextSpacing) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(modeBadge)
                            .font(.appSubCaptionMono)
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8)
                            .frame(height: Self.badgePillHeight)
                            .background(accent.opacity(0.14), in: Capsule())

                        Text(activeTags.isEmpty ? "未设筛选条件" : "已启用 \(activeTags.count) 项条件")
                            .font(.appCaptionMono)
                            .foregroundStyle(activeTags.isEmpty ? Color.secondary : accent)
                            .lineLimit(1)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: Self.badgePillHeight,
                                maxHeight: Self.badgePillHeight,
                                alignment: .leading
                            )
                    }
                    .frame(height: Self.badgePillHeight)

                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(.appLabel)
                        .lineLimit(1)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: Self.titleLineHeight,
                            maxHeight: Self.titleLineHeight,
                            alignment: .leading
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: FilterSheetLayout.bannerHeaderHeight, alignment: .leading)
            }
            .frame(height: FilterSheetLayout.bannerHeaderHeight)

            tagRow
                .frame(
                    maxWidth: .infinity,
                    minHeight: FilterSheetLayout.bannerTagRowHeight,
                    maxHeight: FilterSheetLayout.bannerTagRowHeight,
                    alignment: .leading
                )
        }
        .padding(FilterSheetLayout.cardPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: FilterSheetLayout.summaryBannerHeight,
            maxHeight: FilterSheetLayout.summaryBannerHeight,
            alignment: .topLeading
        )
        .textureBackground(texture: .bubble, radius: 16)
        .frame(height: FilterSheetLayout.summaryBannerHeight)
    }

    @ViewBuilder
    private var tagRow: some View {
        if activeTags.isEmpty {
            HStack(spacing: 6) {
                Text("默认展示全部")
                    .font(.appSubCaptionMono)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .frame(height: FilterSheetLayout.bannerTagChipHeight)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .frame(height: FilterSheetLayout.bannerTagRowHeight, alignment: .leading)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(activeTags, id: \.self) { tag in
                        Text(tag)
                            .font(.appSubCaptionMono)
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8)
                            .frame(height: FilterSheetLayout.bannerTagChipHeight)
                            .background(accent.opacity(0.14), in: Capsule())
                    }
                }
                .frame(height: FilterSheetLayout.bannerTagRowHeight)
            }
            .frame(height: FilterSheetLayout.bannerTagRowHeight)
        }
    }
}

/// 多选分组顶部的显式「全部（默认不限）」切换行。
struct FilterAllOptionRow: View {
    let title: String
    var trailingHint: String = "不限"
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var onAccent: Color {
        FilterSheetLayout.onAccent(for: colorScheme)
    }

    var body: some View {
        Button {
            Haptics.generateIfEnabled(.selectionChanged)
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle.grid.2x2")
                    .font(.appBody)
                    .foregroundStyle(isSelected ? onAccent : .secondary)

                Text(title)
                    .font(.appBody)
                    .foregroundStyle(isSelected ? onAccent : .appLabel)

                Spacer(minLength: 8)

                Text(isSelected ? "当前生效" : trailingHint)
                    .font(.appSubCaptionMono)
                    .foregroundStyle(isSelected ? onAccent.opacity(0.9) : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (isSelected ? onAccent.opacity(0.18) : Color.listItemBackground),
                        in: Capsule()
                    )
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                isSelected ? Color.accentColor : FilterSheetLayout.unselectedFill(for: colorScheme),
                in: RoundedRectangle(cornerRadius: FilterSheetLayout.itemCornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 筛选页底部常驻操作栏：次要「重置」+ 实心高对比主按钮「完成」。
struct FilterBottomActionBar: View {
    let hasActiveFilters: Bool
    let activeCount: Int
    let onReset: () -> Void
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var onAccent: Color {
        FilterSheetLayout.onAccent(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.45)

            HStack(spacing: 12) {
                Button {
                    Haptics.generateIfEnabled(.light)
                    onReset()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.appMono)
                        Text("重置")
                            .font(.appBody)
                    }
                    .foregroundStyle(hasActiveFilters ? Color.appLabel : Color.secondary)
                    .frame(width: 104, height: 48)
                    .background(
                        Color.listItemBackground,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.generateIfEnabled(.medium)
                    onDone()
                } label: {
                    HStack(spacing: 6) {
                        Text("完成")
                            .font(.appHeadline)

                        if activeCount > 0 {
                            Text("\(activeCount)")
                                .font(.appCaptionMono)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(onAccent.opacity(0.2), in: Capsule())
                        }
                    }
                    .foregroundStyle(onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Color.accentColor,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("完成")
            }
            .padding(.horizontal, FilterSheetLayout.horizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }
}

/// 对战 / 打工列表共用的「记录状态」筛选卡片。
struct RecordStatusFilterSection: View {
    @Binding var filter: Filter
    @Environment(\.colorScheme) private var colorScheme

    private var onAccent: Color {
        FilterSheetLayout.onAccent(for: colorScheme)
    }

    private var summaryText: String {
        if filter.showOnlyFavorites {
            return "\(filter.visibility.title) · 仅收藏"
        }
        return filter.visibility.title
    }

    var body: some View {
        ModeDetailSection(
            title: "记录状态",
            trailing: summaryText,
            accent: .spPink
        ) {
            ModeDetailCard(padding: FilterSheetLayout.cardPadding) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("显示范围")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(Filter.RecordVisibility.allCases, id: \.self) { mode in
                                let isSelected = filter.visibility == mode
                                Button {
                                    Haptics.generateIfEnabled(.selectionChanged)
                                    filter.visibility = mode
                                } label: {
                                    Text(mode.title)
                                        .font(.appCaption)
                                        .foregroundStyle(isSelected ? onAccent : .appLabel)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.92)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(
                                            isSelected
                                                ? Color.accentColor
                                                : FilterSheetLayout.unselectedFill(for: colorScheme),
                                            in: RoundedRectangle(
                                                cornerRadius: FilterSheetLayout.innerCornerRadius,
                                                style: .continuous
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        Haptics.generateIfEnabled(.selectionChanged)
                        filter.showOnlyFavorites.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: filter.showOnlyFavorites ? "heart.fill" : "heart")
                                .font(.appBody)
                                .foregroundStyle(filter.showOnlyFavorites ? onAccent : .spPink)
                                .frame(width: 30, height: 30)
                                .background(
                                    filter.showOnlyFavorites
                                        ? onAccent.opacity(0.18)
                                        : Color.spPink.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )

                            Text("只显示收藏")
                                .font(.appBody)
                                .foregroundStyle(filter.showOnlyFavorites ? onAccent : .appLabel)

                            Spacer(minLength: 8)

                            Image(
                                systemName: filter.showOnlyFavorites
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .font(.appHeadline)
                            .foregroundStyle(
                                filter.showOnlyFavorites
                                    ? onAccent
                                    : Color.secondary.opacity(0.45)
                            )
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 48)
                        .background(
                            filter.showOnlyFavorites
                                ? Color.accentColor
                                : FilterSheetLayout.unselectedFill(for: colorScheme),
                            in: RoundedRectangle(
                                cornerRadius: FilterSheetLayout.itemCornerRadius,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
