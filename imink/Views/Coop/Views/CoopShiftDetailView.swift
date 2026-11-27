import SwiftUI
import SplatDatabase

struct CoopShiftDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: CoopListViewModel
    @StateObject var viewModel: CoopShiftDetailViewModel
    @State var showPlayerDetail: Bool = false
    @State var activePlayer: CoopPlayerStatus? = nil
    @State var hoveredMember: Bool = false
    @Binding var navigationPath: NavigationPath

    var id: Int
    init(id: Int, navigationPath: Binding<NavigationPath>) {
        self.id = id
        self._navigationPath = navigationPath
        _viewModel = StateObject(wrappedValue: CoopShiftDetailViewModel(id: id))
    }

    var body: some View {
        Group {
            if viewModel.initialized, let status = viewModel.coopGroupStatus {
                ModeDetailScaffold(
                    header: makeHeader(status: status),
                    metrics: makeMetrics(status: status),
                    shareSummary: makeShareSummary(status: status)
                ) {
                    cardView
                } bodyContent: {
                    if !viewModel.coopWaveStatus.isEmpty {
                        ModeDetailSection(
                            title: "水位与特殊波统计",
                            accent: .salmonRunTheme
                        ) {
                            ModeDetailCard {
                                waveView
                            }
                        }
                    }

                    let kingSorted = viewModel.coopEnemyStatus.filter { $0.nameId.order >= 23 }
                    if !kingSorted.isEmpty {
                        ModeDetailSection(
                            title: "头目联合",
                            trailing: "\(kingSorted.count) 种",
                            accent: .spPink
                        ) {
                            ModeDetailCard {
                                kingView
                            }
                        }
                    }

                    let enemySorted = viewModel.coopEnemyStatus.filter { $0.nameId.order < 23 }
                    if !enemySorted.isEmpty {
                        ModeDetailSection(
                            title: "巨大鲑鱼统计",
                            trailing: "\(enemySorted.count) 种",
                            accent: .spOrange
                        ) {
                            enemyView
                        }
                    }

                    if !viewModel.coopWeaponStatus.isEmpty {
                        ModeDetailSection(
                            title: "使用武器统计",
                            trailing: "\(viewModel.coopWeaponStatus.count) 把",
                            accent: .spGreen
                        ) {
                            weaponView
                        }
                    }

                    if !viewModel.coopPlayerStatus.isEmpty {
                        ModeDetailSection(
                            title: "同行工友",
                            trailing: "\(viewModel.coopPlayerStatus.count) 人",
                            accent: .spYellow
                        ) {
                            playerView
                        }
                    }
                }
            } else {
                LoadingView(size: 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fixSafeareaBackground()
            }
        }
        .navigationTitle("打工班次")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(Popup(
            isPresented: showPlayerDetail,
            onDismiss: {
                showPlayerDetail = false
            },
            content: {
                CoopPlayerStatusView(status: activePlayer, onViewPlayerRecords: { playerName, playerByname, playerNameId in
                    listViewModel.filter.playerName = playerName
                    listViewModel.filter.playerByname = playerByname
                    listViewModel.filter.playerNameId = playerNameId
                    listViewModel.navigationTitle = "\(playerName)的打工记录"
                    Task {
                        await listViewModel.loadCoops()
                    }
                    navigationPath.removeLast(navigationPath.count)
                })
            }
        ))
        .task {
            await viewModel.load()
        }
    }

    var timeSpanText: String? {
        guard let coopGroupStatus = viewModel.coopGroupStatus else { return nil }
        return DateFormat.yearMonthDayHourMinute.string(from: coopGroupStatus.startTime)
            + " - "
            + DateFormat.yearMonthDayHourMinute.string(from: coopGroupStatus.endTime)
    }

    private func makeHeader(status: CoopGroupStatus) -> ModeDetailHeaderConfig {
        let rule = CoopRule(rawValue: status.rule) ?? .REGULAR
        let stageName = status._stage?.nameId.localizedFromSplatNet ?? rule.name
        let subtext: String = status.disconnect > 0
            ? "共 \(status.count) 场 · 掉线 \(status.disconnect)"
            : "共 \(status.count) 场打工"

        return ModeDetailHeaderConfig(
            modeBadge: "打工班次",
            title: stageName,
            subtitle: timeSpanText ?? "",
            accent: .salmonRunTheme,
            icon: rule.icon,
            resultText: "\(status.clear)胜 \(status.failure)败",
            resultColor: .waveClear,
            resultSubtext: subtext
        )
    }

    private func makeMetrics(status: CoopGroupStatus) -> [ModeDetailMetric] {
        let rateText = status.count > 0 ? String(format: "%.1f", status.clearRate * 100) : "--"
        return [
            ModeDetailMetric(
                id: "clearRate",
                label: "班次通关率",
                value: rateText,
                unit: "%",
                valueColor: .waveClear
            ),
            ModeDetailMetric(
                id: "highestEgg",
                label: "最高金蛋",
                value: "\(status.highestEgg)",
                unit: "粒",
                valueColor: .spYellow
            ),
            ModeDetailMetric(
                id: "highestScore",
                label: "最高分数",
                value: status.highestScore.map { "\($0)" } ?? "--",
                unit: status.highestScore != nil ? "分" : nil,
                valueColor: .salmonRunTheme
            ),
            ModeDetailMetric(
                id: "count",
                label: "总场次",
                value: "\(status.count)",
                unit: "场"
            )
        ]
    }

    private func makeShareSummary(status: CoopGroupStatus) -> String {
        let rule = CoopRule(rawValue: status.rule) ?? .REGULAR
        let stageName = status._stage?.nameId.localizedFromSplatNet ?? rule.name
        return "【imink 打工班次】\(stageName) (\(timeSpanText ?? "")) | 共 \(status.count) 场：通关 \(status.clear) / 失败 \(status.failure) | 最高金蛋 \(status.highestEgg)"
    }
}
