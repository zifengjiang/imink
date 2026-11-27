import SwiftUI
import UIKit
import GRDB
import SplatDatabase

struct StageRecordView: View {
    @StateObject var viewModel = StageRecordViewModel()

    private let twoColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(size: 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.stageRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.appDisplay)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, height: 64)
                        .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("暂无场地记录")
                        .font(.appHeadline)
                        .foregroundStyle(.appLabel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        if !viewModel.played.isEmpty {
                            LazyVGrid(columns: twoColumns, spacing: 12) {
                                ForEach(viewModel.played, id: \.nameId) { stage in
                                    RecordRowView(stage: stage, sortedBy: $viewModel.sortedBy)
                                }
                            }
                        }

                        if !viewModel.notPlayed.isEmpty {
                            Text("未游玩的场地")
                                .font(.appHeadline)
                                .foregroundStyle(.appLabel)
                                .padding(.top, 4)

                            LazyVGrid(columns: twoColumns, spacing: 12) {
                                ForEach(viewModel.notPlayed, id: \.nameId) { stage in
                                    RecordRowView(stage: stage, sortedBy: $viewModel.sortedBy)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            Button {
                                Task {
                                    await viewModel.reloadFromRemote()
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }

                            Menu {
                                Picker("排序方式", selection: $viewModel.sortedBy) {
                                    ForEach(StageRecordViewModel.SortedBy.allCases, id: \.self) { sortedBy in
                                        Text(sortedBy.rawValue)
                                            .tag(sortedBy)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("场地记录")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fixSafeareaBackground()
        .task {
            await viewModel.initialLoad()
        }
        .onChange(of: viewModel.sortedBy) { _, _ in
            viewModel.sort()
        }
    }

    struct RecordRowView: View {
        let stage: StageRecord
        @Binding var sortedBy: StageRecordViewModel.SortedBy

        private var stageTitle: String {
            if !stage.nameId.isEmpty {
                let localized = stage.nameId.localizedFromSplatNet
                if !localized.isEmpty {
                    return localized
                }
            }
            return stage.name
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if !stage.name.isEmpty, UIImage(named: stage.name) != nil {
                        Image(stage.name)
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [Color.black.opacity(0.65), Color.black.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .aspectRatio(16 / 9, contentMode: .fit)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text(stageTitle)
                        .font(.appCaption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(6)
                }

                if let lastPlayed = stage.stats?.lastPlayedTime {
                    Text(lastPlayed.toPlayedTimeString())
                        .font(.appSubCaptionMono)
                        .foregroundStyle(sortedBy == .time ? Color.spRed : .secondary)
                        .lineLimit(1)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 4) {
                    ruleCell(label: "占地", rate: stage.stats?.winRateTw, isActive: sortedBy == .turf)
                    ruleCell(label: "区域", rate: stage.stats?.winRateAr, isActive: sortedBy == .area)
                    ruleCell(label: "塔楼", rate: stage.stats?.winRateLf, isActive: sortedBy == .tower)
                    ruleCell(label: "鱼虎", rate: stage.stats?.winRateGl, isActive: sortedBy == .rain)
                    ruleCell(label: "蛤蜊", rate: stage.stats?.winRateCl, isActive: sortedBy == .clam)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        private func ruleCell(label: String, rate: Double?, isActive: Bool) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(label)
                    .font(.appSubCaptionMono)
                    .foregroundStyle(isActive ? Color.spRed : .secondary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(rate.map { String(format: "%.0f%%", $0 * 100) } ?? "--")
                    .font(.appSubCaptionMono)
                    .foregroundStyle(
                        isActive
                            ? Color.spRed
                            : (rate != nil ? Color.appLabel : Color.secondary)
                    )
                    .lineLimit(1)
            }
        }
    }
}

@MainActor
final class StageRecordViewModel: ObservableObject, CachedRecordViewModel {
    typealias Record = [StageRecord]

    @Published var stageRecords: [StageRecord] = []
    @Published var sortedBy: SortedBy = .time
    @Published private(set) var isLoading = true

    var value: [StageRecord]? {
        get { stageRecords.isEmpty ? nil : stageRecords }
        set { stageRecords = newValue ?? [] }
    }

    func readCache() -> [StageRecord]? {
        let cached = AppUserDefaults.shared.stageRecordsCache
        return cached.isEmpty ? nil : cached
    }

    func writeCache(_ records: [StageRecord]) {
        AppUserDefaults.shared.stageRecordsCache = records
    }

    func fetchRemote() async -> [StageRecord]? {
        await SN3Client.shared.fetchRecord(.stageRecord)
    }

    func didUpdateValue() {
        sort()
    }

    func initialLoad() async {
        if let cached = readCache(), !cached.isEmpty {
            stageRecords = cached
            sort()
            isLoading = false
            return
        }
        if let remote = await fetchRemote(), !remote.isEmpty {
            stageRecords = remote
            writeCache(remote)
            sort()
            isLoading = false
            return
        }
        stageRecords = await Self.loadLocalStageFallback(accountId: AppUserDefaults.shared.accountId)
        sort()
        isLoading = false
    }

    func reloadFromRemote() async {
        if let remote = await fetchRemote(), !remote.isEmpty {
            stageRecords = remote
            writeCache(remote)
            sort()
        } else if stageRecords.isEmpty {
            stageRecords = await Self.loadLocalStageFallback(accountId: AppUserDefaults.shared.accountId)
            sort()
        }
    }

    nonisolated private static func loadLocalStageFallback(accountId: Int) async -> [StageRecord] {
        struct RuleCount {
            var wins: Int = 0
            var decided: Int = 0
            var rate: Double? {
                guard decided > 0 else { return nil }
                return Double(wins) / Double(decided)
            }
        }
        struct StageAgg {
            var tw = RuleCount()
            var ar = RuleCount()
            var lf = RuleCount()
            var gl = RuleCount()
            var cl = RuleCount()
            var lastPlayed: Date = .distantPast
        }

        return (try? await SplatDatabase.shared.dbQueue.read { db in
            let battleRows = try Row.fetchAll(
                db,
                sql: """
                SELECT stageId, rule, judgement, playedTime
                FROM battle
                WHERE accountId = ? AND isDeleted = 0
                """,
                arguments: [accountId]
            )
            guard !battleRows.isEmpty else { return [] }

            var byStage: [Int64: StageAgg] = [:]
            for row in battleRows {
                guard let stageId: Int64 = row["stageId"] else { continue }
                let rule: String = (row["rule"] as String?) ?? ""
                let judgement: String = (row["judgement"] as String?) ?? ""
                let isWin = judgement == "WIN"
                let isDecided = isWin || judgement == "LOSE" || judgement == "DRAW" || judgement == "DEEMED_LOSE"

                var agg = byStage[stageId] ?? StageAgg()
                if let playedTime: Date = row["playedTime"], playedTime > agg.lastPlayed {
                    agg.lastPlayed = playedTime
                }
                if isDecided {
                    switch rule {
                    case "TURF_WAR", "TRI_COLOR":
                        agg.tw.decided += 1
                        if isWin { agg.tw.wins += 1 }
                    case "AREA":
                        agg.ar.decided += 1
                        if isWin { agg.ar.wins += 1 }
                    case "LOFT":
                        agg.lf.decided += 1
                        if isWin { agg.lf.wins += 1 }
                    case "GOAL":
                        agg.gl.decided += 1
                        if isWin { agg.gl.wins += 1 }
                    case "CLAM":
                        agg.cl.decided += 1
                        if isWin { agg.cl.wins += 1 }
                    default:
                        break
                    }
                }
                byStage[stageId] = agg
            }

            let stageMapRows = try Row.fetchAll(
                db,
                sql: "SELECT id, nameId, name FROM imageMap WHERE nameId LIKE 'VnNTdGFnZS0%' ORDER BY id ASC"
            )
            return stageMapRows.compactMap { row -> StageRecord? in
                guard let stageId: Int64 = row["id"] else { return nil }
                let nameId = (row["nameId"] as String?) ?? ""
                let name = (row["name"] as String?) ?? ""
                guard !nameId.isEmpty else { return nil }

                if let agg = byStage[stageId] {
                    return StageRecord(
                        name: name,
                        nameId: nameId,
                        stats: StageRecord.Stats(
                            winRateCl: agg.cl.rate,
                            winRateLf: agg.lf.rate,
                            winRateTw: agg.tw.rate,
                            winRateGl: agg.gl.rate,
                            winRateAr: agg.ar.rate,
                            lastPlayedTime: agg.lastPlayed == .distantPast ? Date() : agg.lastPlayed
                        )
                    )
                } else {
                    return StageRecord(name: name, nameId: nameId, stats: nil)
                }
            }
        }) ?? []
    }

    var notPlayed: [StageRecord] {
        stageRecords.filter {
            switch sortedBy {
            case .time:
                $0.stats?.winRateAr == nil && $0.stats?.winRateTw == nil && $0.stats?.winRateLf == nil && $0.stats?.winRateGl == nil && $0.stats?.winRateCl == nil
            case .area:
                $0.stats?.winRateAr == nil
            case .turf:
                $0.stats?.winRateTw == nil
            case .tower:
                $0.stats?.winRateLf == nil
            case .rain:
                $0.stats?.winRateGl == nil
            case .clam:
                $0.stats?.winRateCl == nil
            }
        }
    }

    var played: [StageRecord] {
        stageRecords.filter {
            switch sortedBy {
            case .time:
                $0.stats?.winRateAr != nil || $0.stats?.winRateTw != nil || $0.stats?.winRateLf != nil || $0.stats?.winRateGl != nil || $0.stats?.winRateCl != nil
            case .area:
                $0.stats?.winRateAr != nil
            case .turf:
                $0.stats?.winRateTw != nil
            case .tower:
                $0.stats?.winRateLf != nil
            case .rain:
                $0.stats?.winRateGl != nil
            case .clam:
                $0.stats?.winRateCl != nil
            }
        }
    }

    func sortBy(_ by: SortedBy) {
        sortedBy = by
        sort()
    }

    func sort() {
        let sorted: [StageRecord]
        switch sortedBy {
        case .time:
            sorted = stageRecords.sorted {
                $0.stats?.lastPlayedTime ?? Date(timeIntervalSince1970: 0) > $1.stats?.lastPlayedTime ?? Date(timeIntervalSince1970: 0)
            }
        case .area:
            sorted = stageRecords.sorted { $0.stats?.winRateAr ?? 0 > $1.stats?.winRateAr ?? 0 }
        case .turf:
            sorted = stageRecords.sorted { $0.stats?.winRateTw ?? 0 > $1.stats?.winRateTw ?? 0 }
        case .tower:
            sorted = stageRecords.sorted { $0.stats?.winRateLf ?? 0 > $1.stats?.winRateLf ?? 0 }
        case .rain:
            sorted = stageRecords.sorted { $0.stats?.winRateGl ?? 0 > $1.stats?.winRateGl ?? 0 }
        case .clam:
            sorted = stageRecords.sorted { $0.stats?.winRateCl ?? 0 > $1.stats?.winRateCl ?? 0 }
        }

        withAnimation {
            stageRecords = sorted
        }
    }

    enum SortedBy: String, CaseIterable {
        case time = "上次游玩时间"
        case area = "真格区域"
        case turf = "占地对战"
        case tower = "真格塔楼"
        case rain = "真格鱼虎"
        case clam = "真格蛤蜊"
    }
}

#Preview {
    StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "VnNTdGFnZS0xNg==", stats: .init(winRateCl: 0.778, winRateLf: 0.678, winRateTw: 0.829, winRateGl: 0.231, winRateAr: 0.456)), sortedBy: .constant(.time))
        .frame(width: 180)
        .fixSafeareaBackground()
}
