import SwiftUI
import GRDB
import SplatDatabase

struct FestRecordView: View {
    @StateObject private var viewModel = FestRecordViewModel()
    @ObservedObject private var appState = AppState.shared

    private let kpiColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if !appState.isLogin {
                emptyState(
                    icon: "person.crop.circle.badge.exclamationmark",
                    title: "尚未登录",
                    subtitle: "登录后同步 SplatNet 3 战绩，即可查看祭典场次、胜率与贡献度统计。"
                )
            } else if viewModel.isLoading {
                LoadingView(size: 80)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.groups.isEmpty {
                emptyState(
                    icon: "sparkles",
                    title: "暂无祭典记录",
                    subtitle: "本地尚未保存祭典比赛（FEST）记录，同步包含祭典场次的对战后将自动汇总。"
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LazyVGrid(columns: kpiColumns, spacing: 12) {
                            SWKPICard(
                                title: "祭典场次",
                                value: viewModel.totalMatches.formatted(),
                                icon: "sparkles",
                                tint: .spPink
                            ) {
                                Text("\(viewModel.groups.count) 期班次")
                                    .font(.appCaptionMono)
                                    .foregroundStyle(.secondary)
                            }

                            SWKPICard(
                                title: "祭典胜率",
                                value: viewModel.winRateText,
                                icon: "trophy.fill",
                                tint: .spLightGreen
                            ) {
                                Text("\(viewModel.totalWins)胜 \(viewModel.totalLosses)负")
                                    .font(.appCaptionMono)
                                    .foregroundStyle(.secondary)
                            }

                            SWKPICard(
                                title: "累计贡献度",
                                value: viewModel.totalContribution.formatted(),
                                icon: "flame.fill",
                                tint: .spOrange
                            )

                            SWKPICard(
                                title: "获得祭典贝",
                                value: viewModel.totalJewels.formatted(),
                                icon: "seal.fill",
                                tint: .spYellow
                            ) {
                                if let maxPower = viewModel.peakFestPowerText {
                                    Text("最高 \(maxPower)")
                                        .font(.appCaptionMono)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("祭典班次记录")
                                .font(.appHeadline)
                                .foregroundStyle(.appLabel)
                                .padding(.horizontal, 4)

                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.groups, id: \.groupId) { group in
                                    NavigationLink(destination: BattleShiftDetailView(groupId: Int(group.groupId))) {
                                        BattleListShiftCardView(status: group)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("祭典记录")
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fixSafeareaBackground()
        .task(id: appState.isLogin) {
            await viewModel.load()
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.appDisplay)
                .foregroundStyle(.secondary)
                .frame(width: 68, height: 68)
                .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(title)
                .font(.appHeadline)
                .foregroundStyle(.appLabel)

            Text(subtitle)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
final class FestRecordViewModel: ObservableObject {
    @Published private(set) var groups: [BattleGroupStatus] = []
    @Published private(set) var isLoading = false

    var totalMatches: Int {
        groups.reduce(0) { $0 + $1.count }
    }

    var totalWins: Int {
        groups.reduce(0) { $0 + $1.winCount }
    }

    var totalLosses: Int {
        groups.reduce(0) { $0 + $1.loseCount }
    }

    var totalDisconnects: Int {
        groups.reduce(0) { $0 + $1.disconnectCount }
    }

    var totalContribution: Int {
        groups.reduce(0) { $0 + ($1.festContribution ?? 0) }
    }

    var totalJewels: Int {
        groups.reduce(0) { $0 + ($1.festJewel ?? 0) }
    }

    var winRateText: String {
        let denominator = totalWins + totalLosses + totalDisconnects
        guard denominator > 0 else { return "--" }
        let rate = Double(totalWins) / Double(denominator) * 100
        return String(format: "%.1f%%", rate)
    }

    var peakFestPowerText: String? {
        guard let maxPower = groups.compactMap(\.avgMyFestPower).filter({ $0 > 0 }).max() else {
            return nil
        }
        return String(format: "%.1f", maxPower)
    }

    func load() async {
        guard AppState.shared.isLogin else {
            groups = []
            isLoading = false
            return
        }

        isLoading = true
        let accountId = AppUserDefaults.shared.accountId
        let fetched = (try? await SplatDatabase.shared.dbQueue.read { db in
            try BattleGroupStatus.fetchAll(
                db,
                sql: "SELECT * FROM battle_group_status_view WHERE accountId = ? AND mode = 'FEST' ORDER BY GroupID DESC",
                arguments: [accountId]
            )
        }) ?? []
        groups = fetched
        isLoading = false
    }
}
