import Kingfisher
import SwiftUI

struct MyGearView: View {
    @Environment(\.locale) private var locale

    @StateObject private var viewModel = MyGearViewModel()
    @State private var category: MyGearCategory = .headgear
    @State private var sortOption: MyGearSortOption = .defaultOrder
    @State private var filter = MyGearFilter()
    @State private var isShowingFilters = false
    @State private var isSearchVisible = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        content
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: presentSearch) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(
                                isSearchVisible || hasSearchText
                                    ? Color.accentColor
                                    : Color.primary
                            )
                    }
                    .accessibilityLabel(
                        hasSearchText ? "编辑装备搜索" : "搜索装备"
                    )

                    Button {
                        Haptics.generateIfEnabled(.light)
                        isShowingFilters = true
                    } label: {
                        Image(
                            systemName: filter.selectedFilterCount == 0
                                ? "line.3.horizontal.decrease.circle"
                                : "line.3.horizontal.decrease.circle.fill"
                        )
                    }
                    .disabled(viewModel.collection == nil)
                    .accessibilityLabel(
                        filter.selectedFilterCount == 0
                            ? "筛选装备"
                            : "筛选装备，已选择 \(filter.selectedFilterCount) 项"
                    )

                    Menu {
                        Picker("排序", selection: $sortOption) {
                            ForEach(MyGearSortOption.allCases) { option in
                                Text(option.title)
                                    .tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(
                                sortOption == .defaultOrder
                                    ? Color.primary
                                    : Color.accentColor
                            )
                    }
                    .accessibilityLabel("排序方式：\(sortOption.title)")
                }
            }
            .toolbarTitleMenu {
                ForEach(MyGearCategory.allCases) { option in
                    Button {
                        Haptics.generateIfEnabled(.selectionChanged)
                        category = option
                    } label: {
                        if option == category {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            }
            .safeAreaBar(edge: .top) {
                if isSearchVisible {
                    compactSearchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task(id: interfaceLanguage) {
                await viewModel.load(language: interfaceLanguage)
            }
            .alert(
                "刷新失败",
                isPresented: $viewModel.isShowingRefreshError,
                presenting: viewModel.errorMessage
            ) { _ in
                Button("好", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .sheet(isPresented: $isShowingFilters) {
                if let collection = viewModel.collection {
                    MyGearFilterView(
                        filter: $filter,
                        brands: collection.availableBrands(for: category),
                        primaryGearPowers: collection.availablePrimaryGearPowers(
                            for: category
                        ),
                        additionalGearPowers: collection.availableAdditionalGearPowers(
                            for: category
                        )
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .onChange(of: category) { _, _ in
                retainAvailableFilterSelections()
            }
            .onChange(of: viewModel.collection) { _, _ in
                retainAvailableFilterSelections()
            }
    }

    private var compactSearchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("搜索装备、品牌或技能", text: $filter.searchText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onSubmit {
                        isSearchFocused = false
                    }

                if !filter.searchText.isEmpty {
                    Button {
                        filter.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除搜索")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(.secondary.opacity(0.1), in: Capsule())

            Button("完成", action: dismissSearch)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if let collection = viewModel.collection {
            let gears = collection.gears(
                for: category,
                filteredBy: filter,
                sortedBy: sortOption
            )

            if gears.isEmpty {
                if filter.hasActiveCriteria {
                    ContentUnavailableView {
                        Label(
                            "没有符合条件的装备",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    } description: {
                        Text("尝试更换搜索词或筛选条件。")
                    } actions: {
                        Button("清除搜索和筛选") {
                            filter.reset()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView {
                        Label("暂无\(category.title)", systemImage: "tshirt")
                    } description: {
                        Text("鱿鱼圈 3 中还没有可显示的\(category.title)数据。")
                    } actions: {
                        Button("重新加载") {
                            Task {
                                await viewModel.load(language: interfaceLanguage)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List(gears) { gear in
                    MyGearRow(gear: gear)
                        .listRowInsets(
                            EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16)
                        )
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.load(language: interfaceLanguage)
                }
            }
        } else if viewModel.isLoading {
            MyGearLoadingView()
        } else {
            ContentUnavailableView {
                Label("无法加载装备", systemImage: "wifi.exclamationmark")
            } description: {
                Text(viewModel.errorMessage ?? "请稍后重试。")
            } actions: {
                Button("重试") {
                    Task {
                        await viewModel.load(language: interfaceLanguage)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var interfaceLanguage: String {
        let localization = Bundle.main.preferredLocalizations.first
            ?? AppUserDefaults.shared.currentLanguage
            ?? locale.identifier
        return SplatNetWebLanguage.identifier(for: localization)
    }

    private var hasSearchText: Bool {
        !filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func presentSearch() {
        if !isSearchVisible {
            Haptics.generateIfEnabled(.light)
            withAnimation(.snappy) {
                isSearchVisible = true
            }
        }

        Task { @MainActor in
            await Task.yield()
            isSearchFocused = true
        }
    }

    private func dismissSearch() {
        isSearchFocused = false
        withAnimation(.snappy) {
            isSearchVisible = false
        }
    }

    private func retainAvailableFilterSelections() {
        guard let collection = viewModel.collection else {
            return
        }

        filter.retainAvailableSelections(
            brandIDs: Set(
                collection.availableBrands(for: category).map(\.id)
            ),
            primaryGearPowerIDs: Set(
                collection.availablePrimaryGearPowers(for: category)
                    .map(\.gearPowerID)
            ),
            additionalGearPowerIDs: Set(
                collection.availableAdditionalGearPowers(for: category)
                    .map(\.gearPowerID)
            )
        )
    }
}

@MainActor
final class MyGearViewModel: ObservableObject {
    @Published private(set) var collection: MyGearCollection?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var isShowingRefreshError = false

    func load(language: String) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            let collection = try await SN3Client.shared.fetchMyGearCollection(
                language: language
            )
            try Task.checkCancellation()
            self.collection = collection
        } catch is CancellationError {
            return
        } catch {
            errorMessage = Self.userFacingMessage(for: error)
            isShowingRefreshError = collection != nil
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        if let clientError = error as? SN3Client.Error {
            switch clientError {
            case .invalidGameServiceToken, .invalidBulletToken:
                return "Nintendo 账户登录已失效，请重新登录"
            case .tooManyRequests:
                return "请求过于频繁，请稍后重试"
            case .responseError(let code, _, _):
                return "鱿鱼圈请求失败（\(code)）"
            case .noDetailFetched(let message):
                return "记录详情拉取失败（\(message)）"
            }
        }

        if let decodingError = error as? DecodingError {
            return "响应数据无法解析（\(MyGearResponseDecoder.decodingPath(for: decodingError))）"
        }

        return error.localizedDescription
    }
}

private struct MyGearRow: View {
    let gear: MyGearItem

    var body: some View {
        HStack(spacing: 12) {
            gearThumbnail

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(gear.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(gear.brand.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                abilityRow
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 68)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(gear.displayName)，\(gear.brand.displayName)，主要技能 \(gear.primaryGearPower.name)"
        )
    }

    private var gearThumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.secondary.opacity(0.1))

            MyGearRemoteImageView(
                url: gear.image.resolvedURL,
                placeholderSystemImage: "tshirt.fill"
            )
            .padding(5)

            MyGearRemoteImageView(
                url: gear.brand.image.resolvedURL,
                placeholderSystemImage: "tag.fill"
            )
            .frame(width: 21, height: 21)
            .padding(3)
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .offset(x: 3, y: 3)
        }
        .frame(width: 62, height: 62)
    }

    private var abilityRow: some View {
        HStack(spacing: 6) {
            MyGearAbilityIcon(power: gear.primaryGearPower, size: 29)

            ForEach(0..<3, id: \.self) { index in
                if gear.additionalGearPowers.indices.contains(index) {
                    MyGearAbilityIcon(
                        power: gear.additionalGearPowers[index],
                        size: 23
                    )
                } else {
                    MyGearEmptyAbilitySlot(size: 23)
                }
            }
        }
    }
}

private struct MyGearAbilityIcon: View {
    let power: MyGearPower
    let size: CGFloat

    var body: some View {
        MyGearRemoteImageView(
            url: power.image.resolvedURL,
            placeholderSystemImage: "questionmark"
        )
        .padding(size * 0.12)
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.84), in: Circle())
        .accessibilityLabel(power.name)
    }
}

private struct MyGearEmptyAbilitySlot: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(.secondary.opacity(0.08))
            .overlay {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct MyGearRemoteImageView: View {
    let url: URL?
    let placeholderSystemImage: String

    var body: some View {
        KFImage.url(url, cacheKey: stableCacheKey)
            .placeholder {
                Image(systemName: placeholderSystemImage)
                    .foregroundStyle(.tertiary)
            }
            .cancelOnDisappear(true)
            .resizable()
            .scaledToFit()
    }

    private var stableCacheKey: String? {
        guard let url,
              var components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
              ) else {
            return nil
        }
        components.query = nil
        components.fragment = nil
        return components.string
    }
}

private struct MyGearFilterView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var filter: MyGearFilter
    let brands: [MyGearBrand]
    let primaryGearPowers: [MyGearPower]
    let additionalGearPowers: [MyGearPower]

    private let columns = [
        GridItem(.adaptive(minimum: 78, maximum: 108), spacing: 10),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    brandSection
                    primaryAbilitySection
                    additionalAbilitySection
                }
                .padding(16)
            }
            .navigationTitle("筛选装备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("重置") {
                        filter.clearSelections()
                    }
                    .disabled(filter.selectedFilterCount == 0)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var brandSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "品牌",
                selectedCount: filter.brandIDs.count,
                clear: { filter.brandIDs.removeAll() }
            )

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(brands, id: \.id) { brand in
                    MyGearIconFilterButton(
                        title: brand.displayName,
                        isSelected: filter.brandIDs.contains(brand.id)
                    ) {
                        MyGearRemoteImageView(
                            url: brand.image.resolvedURL,
                            placeholderSystemImage: "tag.fill"
                        )
                        .padding(7)
                    } action: {
                        toggle(brand.id, in: &filter.brandIDs)
                    }
                }
            }
        }
    }

    private var primaryAbilitySection: some View {
        abilitySection(
            title: "主要技能",
            emptyMessage: "当前分类暂无主要技能",
            powers: primaryGearPowers,
            selection: $filter.primaryGearPowerIDs
        )
    }

    private var additionalAbilitySection: some View {
        abilitySection(
            title: "追加技能",
            emptyMessage: "当前分类暂无追加技能",
            powers: additionalGearPowers,
            selection: $filter.additionalGearPowerIDs
        )
    }

    private func abilitySection(
        title: String,
        emptyMessage: String,
        powers: [MyGearPower],
        selection: Binding<Set<Int>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: title,
                selectedCount: selection.wrappedValue.count,
                clear: { selection.wrappedValue.removeAll() }
            )

            if powers.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(powers) { power in
                        MyGearIconFilterButton(
                            title: power.displayName,
                            isSelected: selection.wrappedValue.contains(power.id)
                        ) {
                            MyGearRemoteImageView(
                                url: power.image.resolvedURL,
                                placeholderSystemImage: "questionmark"
                            )
                            .padding(7)
                            .background(Color.black.opacity(0.84), in: Circle())
                            .padding(4)
                        } action: {
                            toggle(power.id, in: &selection.wrappedValue)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(
        title: String,
        selectedCount: Int,
        clear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)

            if selectedCount > 0 {
                Text("已选 \(selectedCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedCount > 0 {
                Button("清除", action: clear)
                    .font(.caption)
            }
        }
    }

    private func toggle<Value: Hashable>(
        _ value: Value,
        in selection: inout Set<Value>
    ) {
        Haptics.generateIfEnabled(.light)
        if selection.contains(value) {
            selection.remove(value)
        } else {
            selection.insert(value)
        }
    }
}

private struct MyGearIconFilterButton<Icon: View>: View {
    let title: String
    let isSelected: Bool
    let icon: Icon
    let action: () -> Void

    init(
        title: String,
        isSelected: Bool,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.icon = icon()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.secondary.opacity(0.09))

                    icon

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(3)
                    }
                }
                .frame(height: 52)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)
            }
            .padding(7)
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .top)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.accentColor
                            : Color.secondary.opacity(0.16),
                        lineWidth: isSelected ? 2 : 0.75
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MyGearLoadingView: View {
    var body: some View {
        List(0..<7, id: \.self) { _ in
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.secondary.opacity(0.16))
                    .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.secondary.opacity(0.16))
                        .frame(width: 142, height: 16)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.secondary.opacity(0.12))
                        .frame(width: 86, height: 11)

                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(.secondary.opacity(index == 0 ? 0.2 : 0.12))
                                .frame(
                                    width: index == 0 ? 29 : 23,
                                    height: index == 0 ? 29 : 23
                                )
                        }
                    }
                }
            }
            .frame(minHeight: 68)
            .redacted(reason: .placeholder)
            .swShimmer(delay: 0.15)
            .listRowInsets(
                EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16)
            )
        }
        .listStyle(.plain)
        .allowsHitTesting(false)
        .accessibilityLabel("正在加载装备")
    }
}
