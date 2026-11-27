import Foundation

enum MyGearCategory: String, CaseIterable, Identifiable, Sendable {
    case headgear
    case clothing
    case shoes

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .headgear:
            return "头饰"
        case .clothing:
            return "衣服"
        case .shoes:
            return "鞋子"
        }
    }
}

enum MyGearSortOption: String, CaseIterable, Identifiable, Sendable {
    case defaultOrder
    case brand
    case primaryAbility

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .defaultOrder:
            return "默认"
        case .brand:
            return "品牌"
        case .primaryAbility:
            return "主要技能"
        }
    }
}

struct MyGearFilter: Equatable, Sendable {
    var searchText = ""
    var brandIDs = Set<String>()
    var primaryGearPowerIDs = Set<Int>()
    var additionalGearPowerIDs = Set<Int>()

    var selectedFilterCount: Int {
        brandIDs.count
            + primaryGearPowerIDs.count
            + additionalGearPowerIDs.count
    }

    var hasActiveCriteria: Bool {
        !normalizedSearchText.isEmpty || selectedFilterCount > 0
    }

    mutating func clearSelections() {
        brandIDs.removeAll()
        primaryGearPowerIDs.removeAll()
        additionalGearPowerIDs.removeAll()
    }

    mutating func reset() {
        searchText = ""
        clearSelections()
    }

    mutating func retainAvailableSelections(
        brandIDs availableBrandIDs: Set<String>,
        primaryGearPowerIDs availablePrimaryGearPowerIDs: Set<Int>,
        additionalGearPowerIDs availableAdditionalGearPowerIDs: Set<Int>
    ) {
        brandIDs.formIntersection(availableBrandIDs)
        primaryGearPowerIDs.formIntersection(availablePrimaryGearPowerIDs)
        additionalGearPowerIDs.formIntersection(availableAdditionalGearPowerIDs)
    }

    fileprivate var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MyGearCollection: Decodable, Equatable, Sendable {
    let headGears: MyGearConnection
    let clothingGears: MyGearConnection
    let shoesGears: MyGearConnection

    func gears(
        for category: MyGearCategory,
        sortedBy sortOption: MyGearSortOption
    ) -> [MyGearItem] {
        gears(
            for: category,
            filteredBy: MyGearFilter(),
            sortedBy: sortOption
        )
    }

    func gears(
        for category: MyGearCategory,
        filteredBy filter: MyGearFilter,
        sortedBy sortOption: MyGearSortOption
    ) -> [MyGearItem] {
        let items = unfilteredGears(for: category)

        let filteredItems = items.filter { gear in
            if !filter.brandIDs.isEmpty,
               !filter.brandIDs.contains(gear.brand.id) {
                return false
            }

            if !filter.primaryGearPowerIDs.isEmpty,
               !filter.primaryGearPowerIDs.contains(
                   gear.primaryGearPower.gearPowerID
               ) {
                return false
            }

            if !filter.additionalGearPowerIDs.isEmpty {
                let additionalIDs = Set(
                    gear.additionalGearPowers.map(\.gearPowerID)
                )
                if additionalIDs.isDisjoint(
                    with: filter.additionalGearPowerIDs
                ) {
                    return false
                }
            }

            return gear.matches(searchText: filter.normalizedSearchText)
        }

        switch sortOption {
        case .defaultOrder:
            return filteredItems
        case .brand:
            return stableSort(filteredItems) {
                let displayNameOrder = $0.brand.displayName
                    .localizedStandardCompare($1.brand.displayName)
                if displayNameOrder != .orderedSame {
                    return displayNameOrder == .orderedAscending
                }
                return $0.brand.id.localizedStandardCompare($1.brand.id)
                    == .orderedAscending
            }
        case .primaryAbility:
            return stableSort(filteredItems) {
                $0.primaryGearPower.gearPowerID < $1.primaryGearPower.gearPowerID
            }
        }
    }

    func availableBrands(for category: MyGearCategory) -> [MyGearBrand] {
        var seenIDs = Set<String>()
        return unfilteredGears(for: category)
            .compactMap { gear in
                seenIDs.insert(gear.brand.id).inserted ? gear.brand : nil
            }
            .sorted {
                let order = $0.displayName.localizedStandardCompare($1.displayName)
                return order == .orderedSame
                    ? $0.id < $1.id
                    : order == .orderedAscending
            }
    }

    func availablePrimaryGearPowers(
        for category: MyGearCategory
    ) -> [MyGearPower] {
        uniquePowers(
            from: unfilteredGears(for: category).map(\.primaryGearPower)
        )
    }

    func availableAdditionalGearPowers(
        for category: MyGearCategory
    ) -> [MyGearPower] {
        uniquePowers(
            from: unfilteredGears(for: category).flatMap(\.additionalGearPowers)
        )
    }

    private func uniquePowers(from powers: [MyGearPower]) -> [MyGearPower] {
        var seenIDs = Set<Int>()
        return powers
            .compactMap { power in
                return seenIDs.insert(power.gearPowerID).inserted ? power : nil
            }
            .sorted {
                let order = $0.displayName.localizedStandardCompare($1.displayName)
                return order == .orderedSame
                    ? $0.id < $1.id
                    : order == .orderedAscending
            }
    }

    private func unfilteredGears(
        for category: MyGearCategory
    ) -> [MyGearItem] {
        switch category {
        case .headgear:
            return headGears.nodes
        case .clothing:
            return clothingGears.nodes
        case .shoes:
            return shoesGears.nodes
        }
    }

    private func stableSort(
        _ items: [MyGearItem],
        areInIncreasingOrder: (MyGearItem, MyGearItem) -> Bool
    ) -> [MyGearItem] {
        items.enumerated()
            .sorted { lhs, rhs in
                if areInIncreasingOrder(lhs.element, rhs.element) {
                    return true
                }
                if areInIncreasingOrder(rhs.element, lhs.element) {
                    return false
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

struct MyGearConnection: Decodable, Equatable, Sendable {
    let nodes: [MyGearItem]
}

struct MyGearItem: Decodable, Equatable, Identifiable, Sendable {
    let headGearID: Int?
    let clothingGearID: Int?
    let shoesGearID: Int?
    let name: String
    let rarity: Int?
    let image: MyGearRemoteImage
    let brand: MyGearBrand
    let primaryGearPower: MyGearPower
    let additionalGearPowers: [MyGearPower]
    let stats: MyGearStats?

    var id: String {
        if let headGearID {
            return "headgear-\(headGearID)"
        }
        if let clothingGearID {
            return "clothing-\(clothingGearID)"
        }
        if let shoesGearID {
            return "shoes-\(shoesGearID)"
        }
        return "gear-\(image.url)-\(name)"
    }

    var displayName: String {
        guard let localizationKey = image.url.imageHash else {
            return name
        }
        let localizedName = localizationKey.localizedFromSplatNet
        return localizedName == localizationKey ? name : localizedName
    }

    fileprivate func matches(searchText: String) -> Bool {
        let terms = searchText
            .split(whereSeparator: { $0.isWhitespace })
            .map { Self.normalizedSearchValue(String($0)) }
        guard !terms.isEmpty else {
            return true
        }

        let powers = [primaryGearPower] + additionalGearPowers
        let candidates = [
            name,
            displayName,
            brand.id,
            brand.name,
            brand.displayName,
        ] + powers.flatMap { power in
            [power.name, power.displayName]
        }

        let normalizedCandidates = candidates.map(Self.normalizedSearchValue)
        return terms.allSatisfy { term in
            normalizedCandidates.contains { candidate in
                candidate.contains(term)
            }
        }
    }

    private static func normalizedSearchValue(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }

    private enum CodingKeys: String, CodingKey {
        case headGearID = "headGearId"
        case clothingGearID = "clothingGearId"
        case shoesGearID = "shoesGearId"
        case name
        case rarity
        case image
        case brand
        case primaryGearPower
        case additionalGearPowers
        case stats
    }
}

struct MyGearRemoteImage: Decodable, Equatable, Sendable {
    let url: String

    var resolvedURL: URL? {
        URL(string: url)
    }
}

struct MyGearBrand: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let image: MyGearRemoteImage

    var displayName: String {
        let localizedName = id.localizedFromSplatNet
        return localizedName == id ? name : localizedName
    }
}

struct MyGearPower: Decodable, Equatable, Identifiable, Sendable {
    let gearPowerID: Int
    let name: String
    let image: MyGearRemoteImage
    let power: Double?

    var id: Int {
        gearPowerID
    }

    var displayName: String {
        guard let localizationKey = image.url.imageHash else {
            return name
        }
        let localizedName = localizationKey.localizedFromSplatNet
        return localizedName == localizationKey ? name : localizedName
    }

    private enum CodingKeys: String, CodingKey {
        case gearPowerID = "gearPowerId"
        case name
        case image
        case power
    }
}

struct MyGearStats: Decodable, Equatable, Sendable {
    let exp: Int?
}

struct MyGearGraphQLResponse: Decodable, Sendable {
    let data: MyGearCollection?
    let errors: [MyGearGraphQLError]?

    func validatedCollection() throws -> MyGearCollection {
        if let message = errors?.compactMap(\.message).first(where: { !$0.isEmpty }) {
            throw MyGearCollectionError.graphQL(message)
        }
        guard let data else {
            throw MyGearCollectionError.missingData
        }
        return data
    }
}

struct MyGearGraphQLError: Decodable, Sendable {
    let message: String
}

struct MyGearGraphQLErrorEnvelope: Decodable, Sendable {
    let errors: [MyGearGraphQLError]?
}

enum MyGearResponseDecoder {
    static func decode(_ responseData: Data) throws -> MyGearCollection {
        let decoder = JSONDecoder()

        do {
            let envelope = try decoder.decode(
                MyGearGraphQLErrorEnvelope.self,
                from: responseData
            )
            if let message = envelope.errors?
                .map(\.message)
                .first(where: { !$0.isEmpty }) {
                throw MyGearCollectionError.graphQL(message)
            }
        } catch let error as MyGearCollectionError {
            throw error
        } catch let error as DecodingError {
            throw MyGearCollectionError.invalidResponse(
                decodingPath(for: error)
            )
        }

        do {
            let response = try decoder.decode(
                MyGearGraphQLResponse.self,
                from: responseData
            )
            return try response.validatedCollection()
        } catch let error as MyGearCollectionError {
            throw error
        } catch let error as DecodingError {
            throw MyGearCollectionError.invalidResponse(
                decodingPath(for: error)
            )
        }
    }

    static func decodingPath(for error: DecodingError) -> String {
        let codingPath: [CodingKey]
        let missingKey: CodingKey?

        switch error {
        case .dataCorrupted(let context):
            codingPath = context.codingPath
            missingKey = nil
        case .keyNotFound(let key, let context):
            codingPath = context.codingPath
            missingKey = key
        case .typeMismatch(_, let context):
            codingPath = context.codingPath
            missingKey = nil
        case .valueNotFound(_, let context):
            codingPath = context.codingPath
            missingKey = nil
        @unknown default:
            return "未知位置"
        }

        let components = codingPath.map(\.stringValue)
            + (missingKey.map { [$0.stringValue] } ?? [])
        return components.isEmpty ? "响应根节点" : components.joined(separator: ".")
    }
}

enum MyGearCollectionError: LocalizedError, Equatable {
    case graphQL(String)
    case missingData
    case invalidAccountResponse
    case invalidBulletTokenResponse
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .graphQL(let message):
            return "鱿鱼圈返回错误：\(message)"
        case .missingData:
            return "没有收到装备数据，请稍后重试"
        case .invalidAccountResponse:
            return "Nintendo 账户响应无法解析，请重新登录后重试"
        case .invalidBulletTokenResponse:
            return "鱿鱼圈登录响应无法解析，请重新登录后重试"
        case .invalidResponse(let path):
            return "装备数据无法解析（\(path)），请更新 imink 后重试"
        }
    }
}

@MainActor
final class MyGearCollectionRequestCache {
    struct Key: Hashable, Sendable {
        let session: SplatNetWebSession
        let interfaceLanguage: String
    }

    static let shared = MyGearCollectionRequestCache()

    private struct Entry {
        let collection: MyGearCollection
        let expiresAt: Date
    }

    private struct ActiveLoad {
        let key: Key
        let generation: Int
        let task: Task<MyGearCollection, Error>
    }

    private let timeToLive: TimeInterval
    private let now: () -> Date
    private var entries = [Key: Entry]()
    private var activeLoad: ActiveLoad?
    private var generation = 0

    init(
        timeToLive: TimeInterval = 5 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.timeToLive = max(0, timeToLive)
        self.now = now
    }

    func value(
        for key: Key,
        loader: @escaping @MainActor () async throws -> MyGearCollection
    ) async throws -> MyGearCollection {
        let currentDate = now()
        entries = entries.filter { $0.value.expiresAt > currentDate }

        if let entry = entries[key] {
            return entry.collection
        }

        if let activeLoad {
            if activeLoad.key == key {
                return try await activeLoad.task.value
            }

            _ = try? await activeLoad.task.value
            try Task.checkCancellation()
            return try await value(for: key, loader: loader)
        }

        let loadGeneration = generation
        let task = Task { @MainActor [weak self] in
            do {
                let collection = try await loader()
                if let self, self.generation == loadGeneration {
                    self.entries[key] = Entry(
                        collection: collection,
                        expiresAt: self.now().addingTimeInterval(self.timeToLive)
                    )
                }
                self?.finishLoad(for: key, generation: loadGeneration)
                return collection
            } catch {
                self?.finishLoad(for: key, generation: loadGeneration)
                throw error
            }
        }
        activeLoad = ActiveLoad(
            key: key,
            generation: loadGeneration,
            task: task
        )
        return try await task.value
    }

    func invalidateAll() {
        generation &+= 1
        entries.removeAll()
        activeLoad?.task.cancel()
        activeLoad = nil
    }

    private func finishLoad(for key: Key, generation: Int) {
        guard activeLoad?.key == key,
              activeLoad?.generation == generation else {
            return
        }
        activeLoad = nil
    }
}
