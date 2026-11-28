import SwiftUI
import SplatDatabase

struct BattleFilterView: View {
    @Binding var showFilterView: Bool
    @Binding var filter: Filter

    var onDismiss: () async -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let twoColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var selectableModes: [BattleMode] {
        BattleMode.allCases.filter { $0 != .all }
    }

    private var onAccent: Color {
        FilterSheetLayout.onAccent(for: colorScheme)
    }

    private var activeSummaryTags: [String] {
        var tags: [String] = []
        for mode in selectableModes where filter.modes.contains(mode.rawValue) {
            tags.append(mode.name)
        }
        for rule in BattleRule.allCases where filter.rules.contains(rule.rawValue) {
            tags.append(rule == .turfWar ? "涂地模式" : rule.name)
        }
        if filter.visibility != .active {
            tags.append(filter.visibility.title)
        }
        if filter.showOnlyFavorites {
            tags.append("只显示收藏")
        }
        return tags
    }

    private var modeTrailingText: String {
        filter.modes.isEmpty
            ? "全部模式"
            : "已选 \(filter.modes.count)/\(selectableModes.count)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FilterSheetLayout.sectionSpacing) {
                    FilterSummaryBanner(
                        modeBadge: "对战",
                        title: "对战记录筛选",
                        accent: .spOrange,
                        icon: Image(.anarchy),
                        activeTags: activeSummaryTags
                    )

                    battleModeSection

                    RecordStatusFilterSection(filter: $filter)
                }
                .padding(.horizontal, FilterSheetLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, FilterSheetLayout.sectionSpacing)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FilterBottomActionBar(
                    hasActiveFilters: !activeSummaryTags.isEmpty,
                    activeCount: activeSummaryTags.count,
                    onReset: {
                        filter = Filter()
                    },
                    onDone: {
                        showFilterView = false
                        Task {
                            await onDismiss()
                        }
                    }
                )
            }
            .environment(\.hasFloatingTabBarInset, true)
            .fixSafeareaBackground()
            .navigationTitle("对战筛选")
            .navigationBarTitleDisplayMode(.inline)
        }
        .appGameTypography()
        .appLineHeight()
    }

    private var battleModeSection: some View {
        ModeDetailSection(
            title: "对战模式",
            trailing: modeTrailingText,
            accent: .spOrange
        ) {
            ModeDetailCard(padding: FilterSheetLayout.cardPadding) {
                VStack(alignment: .leading, spacing: 10) {
                    FilterAllOptionRow(
                        title: "全部对战",
                        trailingHint: "不限模式",
                        isSelected: filter.modes.isEmpty
                    ) {
                        filter.modes.removeAll()
                    }

                    LazyVGrid(columns: twoColumns, spacing: 10) {
                        ForEach(selectableModes, id: \.rawValue) { mode in
                            battleModeTile(mode)
                        }
                    }
                }
            }
        }
    }

    private func battleModeTile(_ mode: BattleMode) -> some View {
        let isSelected = filter.modes.contains(mode.rawValue)

        return Button {
            Haptics.generateIfEnabled(.selectionChanged)
            if isSelected {
                filter.modes.remove(mode.rawValue)
            } else {
                filter.modes.insert(mode.rawValue)
            }
        } label: {
            HStack(spacing: 8) {
                mode.icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .frame(width: 32, height: 32)
                    .background(
                        isSelected
                            ? Color.black.opacity(colorScheme == .dark ? 0.16 : 0.24)
                            : mode.color.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Text(mode.name)
                    .font(.appBody)
                    .foregroundStyle(isSelected ? onAccent : .appLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 2)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.appBody)
                    .foregroundStyle(
                        isSelected ? onAccent : Color.secondary.opacity(0.4)
                    )
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 52)
            .background(
                isSelected
                    ? Color.accentColor
                    : FilterSheetLayout.unselectedFill(for: colorScheme),
                in: RoundedRectangle(
                    cornerRadius: FilterSheetLayout.itemCornerRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.name)
    }
}

#Preview {
    BattleFilterView(
        showFilterView: .constant(true),
        filter: .constant(Filter())
    ) {
        // onDismiss action
    }
}
