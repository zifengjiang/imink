import SwiftUI
import UIKit
import SplatDatabase
import GRDB

/// 打工筛选页的选项与玩家搜索状态。
@MainActor
final class CoopFilterViewModel: ObservableObject {
    @Published private(set) var weaponsByType: [String: [ImageMap]] = [:]
    @Published private(set) var searchResults: [PlayerSearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var stages: [ImageMap] = []

    private var accountId: Int { AppUserDefaults.shared.accountId }

    /// 加载筛选用的地图与武器列表。
    func load() async {
        do {
            async let weapons = CoopRepository.weaponsByType(accountId: accountId)
            async let stages = CoopRepository.stages(accountId: accountId)
            weaponsByType = try await weapons
            self.stages = try await stages
        } catch {
            logError(error)
            weaponsByType = [:]
            stages = []
        }
    }

    /// 按关键词搜索一起打过工的玩家。
    func searchPlayers(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await CoopRepository.searchPlayers(query: query, accountId: accountId)
        } catch {
            logError(error)
            searchResults = []
        }
    }
}

struct CoopFilterView: View {
    @StateObject var viewModel = CoopFilterViewModel()
    @State private var searchText: String = ""
    @State private var showManualPlayerFields: Bool = false
    @State private var minPlayedDate: Date = CoopRepository.earliestPlayedTime()
    @State private var maxPlayedDate: Date = Date()

    @Binding var showFilterView: Bool
    @Binding var filter: Filter

    var onDismiss: () async -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let stageColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let weaponColumns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 5
    )

    private static let weaponCategoryOrder: [String] = [
        "Shooter", "Roller", "Charger", "Slosher", "Spinner",
        "Maneuver", "Shelter", "Blaster", "Brush", "Stringer", "Saber"
    ]

    private static let weaponCategoryNames: [String: String] = [
        "Shooter": "射击枪",
        "Roller": "滚筒",
        "Charger": "蓄力狙击枪",
        "Slosher": "泼桶",
        "Spinner": "旋转枪",
        "Maneuver": "机动枪",
        "Shelter": "防空伞",
        "Blaster": "爆破枪",
        "Brush": "画笔",
        "Stringer": "猎鱼弓",
        "Saber": "刮水刀"
    ]

    private var onAccent: Color {
        FilterSheetLayout.onAccent(for: colorScheme)
    }

    private var safeMaxDate: Date {
        max(maxPlayedDate, minPlayedDate.addingTimeInterval(86_400))
    }

    private var isCustomTimeRange: Bool {
        let startDelta = abs(filter.start.timeIntervalSince(minPlayedDate))
        let endDelta = abs(safeMaxDate.timeIntervalSince(filter.end))
        return startDelta > 3600 && endDelta > 3600 || startDelta > 86_400 || endDelta > 86_400
    }

    private var hasPlayerFilter: Bool {
        !(filter.playerName ?? "").isEmpty ||
        !(filter.playerByname ?? "").isEmpty ||
        !(filter.playerNameId ?? "").isEmpty
    }

    private var sortedWeaponTypes: [String] {
        viewModel.weaponsByType.keys.sorted { lhs, rhs in
            let lIdx = Self.weaponCategoryOrder.firstIndex(of: lhs) ?? Int.max
            let rIdx = Self.weaponCategoryOrder.firstIndex(of: rhs) ?? Int.max
            if lIdx != rIdx {
                return lIdx < rIdx
            }
            return lhs < rhs
        }
    }

    private var activeSummaryTags: [String] {
        var tags: [String] = []
        if isCustomTimeRange {
            tags.append("自定义时段")
        }
        if filter.visibility != .active {
            tags.append(filter.visibility.title)
        }
        if filter.showOnlyFavorites {
            tags.append("只显示收藏")
        }
        if !filter.stageIds.isEmpty {
            tags.append("地图 \(filter.stageIds.count) 张")
        }
        if hasPlayerFilter {
            tags.append("指定工友")
        }
        if !filter.weaponIds.isEmpty {
            tags.append("武器 \(filter.weaponIds.count) 把")
        }
        return tags
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FilterSheetLayout.sectionSpacing) {
                    FilterSummaryBanner(
                        modeBadge: "鲑鱼跑",
                        title: "打工记录筛选",
                        accent: .spGreen,
                        icon: Image(.salmonRun),
                        activeTags: activeSummaryTags
                    )

                    timeRangeSection

                    RecordStatusFilterSection(filter: $filter)

                    stageSection

                    playerSection

                    if !sortedWeaponTypes.isEmpty {
                        weaponSection
                    }
                }
                .padding(.horizontal, FilterSheetLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, FilterSheetLayout.sectionSpacing)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FilterBottomActionBar(
                    hasActiveFilters: !activeSummaryTags.isEmpty,
                    activeCount: activeSummaryTags.count,
                    onReset: {
                        var reset = Filter()
                        reset.start = minPlayedDate
                        reset.end = maxPlayedDate
                        filter = reset
                        searchText = ""
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
            .navigationTitle("打工筛选")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if hasPlayerFilter {
                    showManualPlayerFields = true
                }
                await viewModel.load()
            }
        }
        .appGameTypography()
        .appLineHeight()
    }

    // MARK: - 1. 时间范围

    private var timeRangeSection: some View {
        let days = max(0, Int(filter.end.timeIntervalSince(filter.start) / 86_400))
        let trailingText = isCustomTimeRange ? "跨度 \(days) 天" : "全部时段"

        return ModeDetailSection(
            title: "时间范围",
            trailing: trailingText,
            accent: .spGreen
        ) {
            ModeDetailCard(padding: FilterSheetLayout.cardPadding) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        dateValueTile(label: "开始日期", date: filter.start, alignment: .leading)
                        dateValueTile(label: "结束日期", date: filter.end, alignment: .trailing)
                    }

                    GeometryReader { geo in
                        if geo.size.width > 40 {
                            let sliderTrackWidth = geo.size.width - 24
                            TimeRangeSlider(
                                lineHeight: 6,
                                lineWidth: sliderTrackWidth,
                                lineCornerRadius: 3,
                                circleWidth: 24,
                                circleShadowRadius: 6,
                                circleBorder: 3,
                                minDate: minPlayedDate,
                                maxDate: safeMaxDate,
                                leftCircleBorderColor: .accentColor,
                                rightCircleBorderColor: .accentColor,
                                leftCircleColor: Color.listItemBackground,
                                rightCircleColor: Color.listItemBackground,
                                lineColorInRange: AnyShapeStyle(Color.accentColor),
                                lineColorOutOfRange: Color.secondary.opacity(0.22),
                                shadow: Color.black.opacity(0.12),
                                startDate: $filter.start,
                                endDate: $filter.end
                            )
                            .id(Int(sliderTrackWidth.rounded()))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(height: 26)
                }
            }
        }
    }

    private func dateValueTile(
        label: String,
        date: Date,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)

            Text(Self.shortDateFormatter.string(from: date))
                .font(.appMono)
                .foregroundStyle(.appLabel)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .background(
            FilterSheetLayout.unselectedFill(for: colorScheme),
            in: RoundedRectangle(cornerRadius: FilterSheetLayout.innerCornerRadius, style: .continuous)
        )
    }

    // MARK: - 2. 地图筛选

    private var stageSection: some View {
        let trailing = filter.stageIds.isEmpty
            ? "全部地图"
            : "已选 \(filter.stageIds.count) 张"

        return ModeDetailSection(
            title: "地图筛选",
            trailing: trailing,
            accent: .spOrange
        ) {
            ModeDetailCard(padding: FilterSheetLayout.cardPadding) {
                VStack(alignment: .leading, spacing: 10) {
                    FilterAllOptionRow(
                        title: "全部地图",
                        trailingHint: "不限场地",
                        isSelected: filter.stageIds.isEmpty
                    ) {
                        filter.stageIds.removeAll()
                    }

                    if !viewModel.stages.isEmpty {
                        LazyVGrid(columns: stageColumns, spacing: 10) {
                            ForEach(viewModel.stages, id: \.hash) { stage in
                                if let rawId = stage.id {
                                    stageTile(stage: stage, stageId: Int(rawId))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func stageTile(stage: ImageMap, stageId: Int) -> some View {
        let isSelected = filter.stageIds.contains(stageId)
        let title = stage.nameId.localizedFromSplatNet

        return Button {
            Haptics.generateIfEnabled(.selectionChanged)
            if isSelected {
                filter.stageIds.remove(stageId)
            } else {
                filter.stageIds.insert(stageId)
            }
        } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if UIImage(named: stage.name) != nil {
                            Image(stage.name)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.black.opacity(0.75)
                        }
                    }
                    .frame(height: 54)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay {
                        if isSelected {
                            Color.accentColor.opacity(0.22)
                        }
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.appBody)
                            .foregroundStyle(onAccent)
                            .padding(3)
                            .background(Color.accentColor, in: Circle())
                            .padding(6)
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 8,
                        style: .continuous
                    )
                )

                Text(title)
                    .font(.appCaption)
                    .appLineHeight(AppFontScale.caption)
                    .foregroundStyle(isSelected ? onAccent : .appLabel)
                    .lineLimit(2)
                    .minimumScaleFactor(0.92)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34, alignment: .leading)
                    .padding(.horizontal, 8)
            }
            .padding(2)
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
        .accessibilityLabel(title)
    }

    // MARK: - 3. 玩家筛选

    private var playerSection: some View {
        ModeDetailSection(
            title: "玩家筛选",
            trailing: hasPlayerFilter ? "已指定工友" : "不限工友",
            accent: .spPurple
        ) {
            ModeDetailCard(padding: FilterSheetLayout.cardPadding) {
                VStack(alignment: .leading, spacing: 10) {
                    if hasPlayerFilter {
                        activePlayerSummaryRow
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        TextField("搜索一起打过工的玩家昵称", text: $searchText)
                            .font(.appBody)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: searchText) { _, newValue in
                                Task {
                                    await viewModel.searchPlayers(query: newValue)
                                }
                            }

                        if viewModel.isSearching {
                            ProgressView()
                                .controlSize(.small)
                        } else if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.appBody)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(
                        FilterSheetLayout.unselectedFill(for: colorScheme),
                        in: RoundedRectangle(
                            cornerRadius: FilterSheetLayout.itemCornerRadius,
                            style: .continuous
                        )
                    )

                    if !viewModel.searchResults.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(viewModel.searchResults) { result in
                                playerSearchResultRow(result)
                            }
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showManualPlayerFields.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.appSubCaptionMono)
                            Text("精确输入名称 / 昵称 / ID")
                                .font(.appCaption)
                            Spacer()
                            Image(systemName: showManualPlayerFields ? "chevron.up" : "chevron.down")
                                .font(.appSubCaptionMono)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showManualPlayerFields {
                        VStack(alignment: .leading, spacing: 8) {
                            manualTextField(
                                label: "玩家名称",
                                placeholder: "输入玩家名称",
                                text: Binding(
                                    get: { filter.playerName ?? "" },
                                    set: { filter.playerName = $0.isEmpty ? nil : $0 }
                                )
                            )

                            manualTextField(
                                label: "玩家昵称",
                                placeholder: "输入玩家昵称",
                                text: Binding(
                                    get: { filter.playerByname ?? "" },
                                    set: { filter.playerByname = $0.isEmpty ? nil : $0 }
                                )
                            )

                            manualTextField(
                                label: "玩家 ID",
                                placeholder: "输入玩家 ID",
                                text: Binding(
                                    get: { filter.playerNameId ?? "" },
                                    set: { filter.playerNameId = $0.isEmpty ? nil : $0 }
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private var activePlayerSummaryRow: some View {
        let parts = [
            filter.playerName,
            filter.playerByname,
            filter.playerNameId.map { "#\($0)" }
        ].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        return HStack(spacing: 8) {
            Image(systemName: "person.crop.circle.fill.badge.checkmark")
                .font(.appBody)
                .foregroundStyle(onAccent)

            Text(parts.joined(separator: " · "))
                .font(.appBody)
                .foregroundStyle(onAccent)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                Haptics.generateIfEnabled(.light)
                filter.playerName = nil
                filter.playerByname = nil
                filter.playerNameId = nil
            } label: {
                Text("清除")
                    .font(.appCaption)
                    .foregroundStyle(onAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(onAccent.opacity(0.2), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(
            Color.accentColor,
            in: RoundedRectangle(cornerRadius: FilterSheetLayout.itemCornerRadius, style: .continuous)
        )
    }

    private func playerSearchResultRow(_ result: PlayerSearchResult) -> some View {
        let isSelected = filter.playerName == result.name &&
            filter.playerByname == result.byname &&
            filter.playerNameId == result.nameId

        return Button {
            Haptics.generateIfEnabled(.selectionChanged)
            filter.playerName = result.name
            filter.playerByname = result.byname
            filter.playerNameId = result.nameId
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.displayName)
                        .font(.appBody)
                        .foregroundStyle(isSelected ? onAccent : .appLabel)
                        .lineLimit(1)

                    Text("同工 \(result.playCount) 场")
                        .font(.appCaptionMono)
                        .foregroundStyle(isSelected ? onAccent.opacity(0.85) : .secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.appBody)
                    .foregroundStyle(isSelected ? onAccent : Color.secondary.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

    private func manualTextField(
        label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            TextField(placeholder, text: text)
                .font(.appBody)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            FilterSheetLayout.unselectedFill(for: colorScheme),
            in: RoundedRectangle(cornerRadius: FilterSheetLayout.innerCornerRadius, style: .continuous)
        )
    }

    // MARK: - 4. 武器筛选

    private var weaponSection: some View {
        let trailing = filter.weaponIds.isEmpty
            ? "全部武器"
            : "已选 \(filter.weaponIds.count) 把"

        return ModeDetailSection(
            title: "武器筛选",
            trailing: trailing,
            accent: .spYellow
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ModeDetailCard(padding: FilterSheetLayout.cardPadding) {
                    FilterAllOptionRow(
                        title: "全部武器",
                        trailingHint: "不限配发",
                        isSelected: filter.weaponIds.isEmpty
                    ) {
                        filter.weaponIds.removeAll()
                    }
                }

                ForEach(sortedWeaponTypes, id: \.self) { type in
                    if let weapons = viewModel.weaponsByType[type], !weapons.isEmpty {
                        weaponCategoryCard(type: type, weapons: weapons)
                    }
                }
            }
        }
    }

    private func weaponCategoryCard(type: String, weapons: [ImageMap]) -> some View {
        let categoryIds = Set(weapons.compactMap { $0.id.map(Int.init) })
        let selectedInCategory = filter.weaponIds.intersection(categoryIds).count
        let categoryTitle = Self.weaponCategoryNames[type] ?? type

        return ModeDetailCard(padding: FilterSheetLayout.cardPadding) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(categoryTitle)
                        .font(.appBody)
                        .foregroundStyle(.appLabel)

                    Spacer()

                    if selectedInCategory > 0 {
                        Text("已选 \(selectedInCategory)")
                            .font(.appSubCaptionMono)
                            .foregroundStyle(onAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    } else {
                        Text("\(weapons.count) 把")
                            .font(.appSubCaptionMono)
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: weaponColumns, spacing: 8) {
                    ForEach(weapons, id: \.hash) { weapon in
                        if let rawId = weapon.id {
                            weaponTile(weapon: weapon, weaponId: Int(rawId))
                        }
                    }
                }
            }
        }
    }

    private func weaponTile(weapon: ImageMap, weaponId: Int) -> some View {
        let isSelected = filter.weaponIds.contains(weaponId)

        return Button {
            Haptics.generateIfEnabled(.selectionChanged)
            if isSelected {
                filter.weaponIds.remove(weaponId)
            } else {
                filter.weaponIds.insert(weaponId)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if UIImage(named: weapon.name) != nil {
                        Image(weapon.name)
                            .resizable()
                            .scaledToFit()
                            .padding(7)
                    } else {
                        Image(systemName: "scope")
                            .font(.appBody)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    isSelected ? Color.accentColor : Color.black.opacity(0.78),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(onAccent.opacity(0.35), lineWidth: 1.5)
                    }
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.appSubCaptionMono)
                        .foregroundStyle(onAccent)
                        .padding(3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weapon.nameId.localizedFromSplatNet)
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
}

extension CoopFilterViewModel {
    static let preview = CoopFilterViewModel()
}

#Preview {
    CoopFilterView(
        viewModel: .preview,
        showFilterView: .constant(true),
        filter: .constant(Filter())
    ) {
    }
}
