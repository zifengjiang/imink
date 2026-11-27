import SwiftUI
import UIKit
import GRDB
import SplatDatabase
import SwiftyJSON

struct WeaponRecordView: View {
    @StateObject var viewModel = WeaponRecordViewModel()
    @State private var showingSortOptions = false

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(size: 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sortedRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "scope")
                        .font(.appDisplay)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, height: 64)
                        .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("暂无武器记录")
                        .font(.appHeadline)
                        .foregroundStyle(.appLabel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(viewModel.sortedRecords, id: \.name.nameId) { record in
                            RecordView(record: record, sortBy: viewModel.sortBy)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("武器记录")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fixSafeareaBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        Task {
                            await viewModel.reloadFromRemote()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }

                    Button {
                        showingSortOptions = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
        .confirmationDialog("更改排序", isPresented: $showingSortOptions, titleVisibility: .visible) {
            Button("常用武器") { viewModel.sortBy = .frequentlyUsed }
            Button("主要武器") { viewModel.sortBy = .mainWeapon }
            Button("次要武器") { viewModel.sortBy = .subWeapon }
            Button("特殊武器") { viewModel.sortBy = .specialWeapon }
            Button("涂墨点数") { viewModel.sortBy = .paint }
            Button("熟练度") { viewModel.sortBy = .level }
            Button("距熟练度提升还剩") { viewModel.sortBy = .expToLevelUp }
            Button("胜利数") { viewModel.sortBy = .wins }
        }
    }

    struct RecordView: View {
        let record: WeaponRecord
        var sortBy: WeaponRecordViewModel.SortOption = .frequentlyUsed

        private var weaponTitle: String {
            if !record.name.nameId.isEmpty {
                let localized = record.name.nameId.localizedFromSplatNet
                if !localized.isEmpty {
                    return localized
                }
            }
            return record.name.name.isEmpty ? "未知武器" : record.name.name
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(0..<max(0, min(record.stats.level, 5)), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundStyle(.spYellow)
                            .font(.appSubCaptionMono)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 14)

                ZStack(alignment: .bottomLeading) {
                    Group {
                        if !record.name.name.isEmpty, UIImage(named: record.name.name) != nil {
                            Image(record.name.name)
                                .resizable()
                                .scaledToFit()
                                .padding(8)
                        } else {
                            Image(systemName: "scope")
                                .font(.appTitle)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .background(Color.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 4) {
                        if !record.subWeapon.name.isEmpty {
                            SpecialWeaponImage(imageName: record.subWeapon.name, size: 15)
                                .padding(2)
                                .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        if !record.specialWeapon.name.isEmpty {
                            SpecialWeaponImage(imageName: record.specialWeapon.name, size: 15)
                                .padding(2)
                                .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    .padding(5)
                }

                Text(weaponTitle)
                    .font(.appCaption)
                    .foregroundStyle(.appLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(record.stats.win)胜")
                        .font(.appMono)
                        .foregroundStyle(.spLightGreen)
                    Spacer(minLength: 2)
                    Text(Self.compactPaint(record.stats.paint))
                        .font(.appSubCaptionMono)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if sortBy == .expToLevelUp && record.stats.expToLevelUp > 0 {
                    Text("差 \(record.stats.expToLevelUp)")
                        .font(.appSubCaptionMono)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        private static func compactPaint(_ paint: Int) -> String {
            if paint >= 10_000 {
                return String(format: "%.1fwp", Double(paint) / 10_000)
            }
            return "\(paint)p"
        }
    }
}

@MainActor
final class WeaponRecordViewModel: ObservableObject, CachedRecordViewModel {
    typealias Record = WeaponRecords

    @Published var weaponRecords: WeaponRecords?
    @Published private(set) var localFallbackRecords: [WeaponRecord] = []
    @Published private(set) var isLoading = true

    var value: WeaponRecords? {
        get { weaponRecords }
        set { weaponRecords = newValue }
    }

    @Published var sortBy: SortOption = .frequentlyUsed {
        didSet {
            objectWillChange.send()
        }
    }

    enum SortOption {
        case frequentlyUsed
        case mainWeapon
        case subWeapon
        case specialWeapon
        case paint
        case level
        case expToLevelUp
        case wins
    }

    var sortedRecords: [WeaponRecord] {
        let records = weaponRecords?.records ?? localFallbackRecords
        guard !records.isEmpty else { return [] }

        switch sortBy {
        case .frequentlyUsed:
            return records.sorted { $0.stats.lastUsedTime ?? .distantPast > $1.stats.lastUsedTime ?? .distantPast }
        case .mainWeapon:
            return records.sorted { $0.name.nameId < $1.name.nameId }
        case .subWeapon:
            return records.sorted { $0.subWeapon.nameId < $1.subWeapon.nameId }
        case .specialWeapon:
            return records.sorted { $0.specialWeapon.nameId < $1.specialWeapon.nameId }
        case .paint:
            return records.sorted { $0.stats.paint > $1.stats.paint }
        case .level:
            return records.sorted { $0.stats.level > $1.stats.level }
        case .expToLevelUp:
            return records.sorted { $0.stats.expToLevelUp < $1.stats.expToLevelUp }
        case .wins:
            return records.sorted { $0.stats.win > $1.stats.win }
        }
    }

    func readCache() -> WeaponRecords? {
        AppUserDefaults.shared.weaponRecordsCache
    }

    func writeCache(_ record: WeaponRecords) {
        AppUserDefaults.shared.weaponRecordsCache = record
    }

    func fetchRemote() async -> WeaponRecords? {
        await SN3Client.shared.fetchRecord(.weaponRecord)
    }

    init() {
        Task { await initialLoad() }
    }

    func initialLoad() async {
        if let cached = readCache(), !cached.records.isEmpty {
            weaponRecords = cached
            isLoading = false
            return
        }
        if let remote = await fetchRemote(), !remote.records.isEmpty {
            weaponRecords = remote
            writeCache(remote)
            isLoading = false
            return
        }
        localFallbackRecords = await Self.loadLocalWeaponFallback(accountId: AppUserDefaults.shared.accountId)
        isLoading = false
    }

    func reloadFromRemote() async {
        if let remote = await fetchRemote(), !remote.records.isEmpty {
            weaponRecords = remote
            writeCache(remote)
        } else if weaponRecords == nil && localFallbackRecords.isEmpty {
            localFallbackRecords = await Self.loadLocalWeaponFallback(accountId: AppUserDefaults.shared.accountId)
        }
    }

    nonisolated private static func loadLocalWeaponFallback(accountId: Int) async -> [WeaponRecord] {
        struct Agg {
            let mainId: UInt16
            let specialId: UInt16
            let subId: UInt16
            var wins: Int = 0
            var paint: Int = 0
            var matches: Int = 0
            var lastUsed: Date = .distantPast
        }

        return (try? await SplatDatabase.shared.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT p.weapon AS weapon,
                       b.judgement AS judgement,
                       COALESCE(p.paint, 0) AS paint,
                       b.playedTime AS playedTime
                FROM battle b
                JOIN vsTeam t ON t.battleId = b.id
                JOIN player p ON p.vsTeamId = t.id AND p.isMyself = 1 AND p.isCoop = 0
                WHERE b.accountId = ? AND b.isDeleted = 0
                """,
                arguments: [accountId]
            )
            guard !rows.isEmpty else { return [] }

            var buckets: [UInt16: Agg] = [:]
            var neededIds: Set<UInt16> = []

            for row in rows {
                guard let packed = PackableNumbers.fromDatabaseValue(row["weapon"]) else { continue }
                let mainId = packed[0]
                let specialId = packed[1]
                let subId = packed[2]
                neededIds.insert(mainId)
                neededIds.insert(specialId)
                neededIds.insert(subId)

                var agg = buckets[mainId] ?? Agg(mainId: mainId, specialId: specialId, subId: subId)
                agg.matches += 1
                if (row["judgement"] as String?) == "WIN" {
                    agg.wins += 1
                }
                agg.paint += (row["paint"] as Int?) ?? 0
                if let playedTime: Date = row["playedTime"], playedTime > agg.lastUsed {
                    agg.lastUsed = playedTime
                }
                buckets[mainId] = agg
            }

            guard !buckets.isEmpty else { return [] }

            let idList = neededIds.map(String.init).joined(separator: ",")
            var mapById: [UInt16: ImageMap] = [:]
            if let mapRows = try? Row.fetchAll(
                db,
                sql: "SELECT id, nameId, name, hash FROM imageMap WHERE id IN (\(idList))"
            ) {
                for r in mapRows {
                    if let rawId: Int64 = r["id"] {
                        let key = UInt16(clamping: rawId)
                        mapById[key] = ImageMap(
                            id: rawId,
                            nameId: (r["nameId"] as String?) ?? "",
                            name: (r["name"] as String?) ?? "",
                            hash: (r["hash"] as String?) ?? ""
                        )
                    }
                }
            }

            return buckets.values.map { agg in
                let mainMap = mapById[agg.mainId] ?? ImageMap(id: Int64(agg.mainId), nameId: "weapon-\(agg.mainId)", name: "", hash: "")
                let subMap = mapById[agg.subId] ?? ImageMap(id: Int64(agg.subId), nameId: "", name: "", hash: "")
                let specialMap = mapById[agg.specialId] ?? ImageMap(id: Int64(agg.specialId), nameId: "", name: "", hash: "")
                let estimatedLevel: Int = {
                    switch agg.paint {
                    case 1_160_000...: return 5
                    case 160_000...: return 4
                    case 60_000...: return 3
                    case 25_000...: return 2
                    case 10_000...: return 1
                    default: return agg.wins >= 5 ? 1 : 0
                    }
                }()
                return WeaponRecord(
                    name: mainMap,
                    level: estimatedLevel,
                    win: agg.wins,
                    paint: agg.paint,
                    subWeapon: subMap,
                    specialWeapon: specialMap,
                    lastUsedTime: agg.lastUsed
                )
            }
        }) ?? []
    }
}

#Preview {
    HStack {
        WeaponRecordView.RecordView(record: WeaponRecord(name: .init(nameId: "V2VhcG9uLTA=", name: "Wst_Brush_Heavy_00", hash: ""), level: 3, win: 560, paint: 23123, subWeapon: .init(nameId: "U3ViV2VhcG9uLTY=", name: "Wsp_SpChariot", hash: ""), specialWeapon: .init(nameId: "U3BlY2lhbFdlYXBvbi0xMQ==", name: "Wsb_Bomb_Curling", hash: "")))
    }
}

extension WeaponRecord {
    init(
        name: ImageMap,
        level: Int,
        win: Int,
        paint: Int,
        subWeapon: ImageMap,
        specialWeapon: ImageMap,
        lastUsedTime: Date? = nil
    ) {
        self.name = name
        self.stats = Stats(expToLevelUp: 0, vibes: 0, level: level, win: win, paint: paint, lastUsedTime: lastUsedTime)
        self.subWeapon = subWeapon
        self.specialWeapon = specialWeapon
        self.category = 0
    }
}

extension WeaponRecord.Stats {
    init(expToLevelUp: Int, vibes: Int, level: Int, win: Int, paint: Int, lastUsedTime: Date?) {
        self.expToLevelUp = expToLevelUp
        self.vibes = vibes
        self.level = level
        self.win = win
        self.paint = paint
        self.lastUsedTime = lastUsedTime
    }
}
