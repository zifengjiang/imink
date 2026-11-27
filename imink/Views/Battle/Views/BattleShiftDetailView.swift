import SwiftUI
import SplatDatabase

struct BattleShiftDetailView: View {
    @StateObject private var viewModel: BattleShiftDetailViewModel
    @State private var activeStageIndex = 0
    @State private var activePlayer: Player?
    @State private var showPlayerSkill = false

    init(groupId: Int) {
        _viewModel = StateObject(wrappedValue: BattleShiftDetailViewModel(groupId: groupId))
    }

    private var battleMode: BattleMode {
        viewModel.status.flatMap { BattleMode(rawValue: $0.mode) } ?? .regular
    }

    var body: some View {
        Group {
            if viewModel.initialized {
                ModeDetailScaffold(
                    header: makeHeader(),
                    metrics: makeMetrics(),
                    shareSummary: makeShareSummary()
                ) {
                    VStack(spacing: 10) {
                        stageCarousel

                        HStack(spacing: 8) {
                            BattleShiftSummaryMetric(title: "胜场", value: "\(viewModel.summary.winCount)", color: .spLightGreen)
                            BattleShiftSummaryMetric(title: "负场", value: "\(viewModel.summary.loseCount)", color: .spPink)
                            BattleShiftSummaryMetric(title: "平局", value: "\(viewModel.summary.drawCount)", color: .spYellow)
                            BattleShiftSummaryMetric(title: "地图 / 武器", value: "\(viewModel.summary.stageCount)/\(viewModel.summary.weaponCount)", color: .appLabel)
                        }
                    }
                } bodyContent: {
                    if !viewModel.summary.ruleBuckets.isEmpty {
                        ModeDetailSection(
                            title: "规则分布",
                            trailing: "共 \(viewModel.summary.totalCount) 场",
                            accent: battleMode.color
                        ) {
                            ModeDetailCard {
                                VStack(spacing: 10) {
                                    ForEach(viewModel.summary.ruleBuckets, id: \.rule) { bucket in
                                        BattleShiftRuleChartRow(bucket: bucket, maxCount: maxRuleCount)
                                    }
                                }
                            }
                        }
                    }

                    if !viewModel.weaponItems.isEmpty {
                        ModeDetailSection(
                            title: "使用武器",
                            trailing: "\(viewModel.weaponItems.count) 把",
                            accent: .spOrange
                        ) {
                            ModeDetailCard {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                                    ForEach(viewModel.weaponItems) { weapon in
                                        VStack(spacing: 4) {
                                            Image(weapon.imageName)
                                                .resizable()
                                                .scaledToFit()
                                                .padding(6)
                                                .frame(height: 48)
                                                .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            Text("x\(weapon.count)")
                                                .font(.appCaptionMono)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    playerSection(title: "同行队友", players: viewModel.teammatePlayers, accent: .spLightGreen)
                    playerSection(title: "交手对手", players: viewModel.opponentPlayers, accent: .spPink)
                }
            } else {
                LoadingView(size: 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fixSafeareaBackground()
            }
        }
        .navigationTitle("对战班次")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(Popup(
            isPresented: showPlayerSkill,
            onDismiss: {
                showPlayerSkill = false
            },
            content: {
                BattlePlayerView(player: activePlayer)
            }
        ))
        .onAppear {
            viewModel.load()
        }
    }

    private func makeHeader() -> ModeDetailHeaderConfig {
        ModeDetailHeaderConfig(
            modeBadge: "对战班次",
            title: battleMode.name,
            subtitle: timeSpanText,
            accent: battleMode.color,
            icon: battleMode.icon,
            resultText: "\(viewModel.summary.winCount)胜 \(viewModel.summary.loseCount)负",
            resultColor: .spLightGreen,
            resultSubtext: "共 \(viewModel.summary.totalCount) 场对战"
        )
    }

    private func makeMetrics() -> [ModeDetailMetric] {
        let winRate: String = {
            let denom = max(viewModel.summary.winCount + viewModel.summary.loseCount, 1)
            guard viewModel.summary.totalCount > 0 else { return "--" }
            return String(format: "%.1f", Double(viewModel.summary.winCount) / Double(denom) * 100)
        }()

        return [
            ModeDetailMetric(
                id: "winRate",
                label: "班次胜率",
                value: winRate,
                unit: "%",
                valueColor: .spLightGreen
            ),
            ModeDetailMetric(
                id: "kd",
                label: "综合 KD",
                value: String(format: "%.2f", viewModel.summary.kd),
                unit: "比值",
                valueColor: battleMode.color
            ),
            ModeDetailMetric(
                id: "kad",
                label: "综合 KA/D",
                value: String(format: "%.2f", viewModel.summary.kad),
                unit: "含助攻"
            ),
            ModeDetailMetric(
                id: "total",
                label: "总场次",
                value: "\(viewModel.summary.totalCount)",
                unit: "场"
            )
        ]
    }

    private var stageCarousel: some View {
        ZStack(alignment: .bottomLeading) {
            if viewModel.stageItems.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.2))
                    .overlay {
                        Text("暂无地图")
                            .font(.appHeadline)
                            .foregroundStyle(.secondary)
                    }
            } else {
                CarouselView(activeIndex: $activeStageIndex, autoScrollDuration: 4.5) {
                    ForEach(viewModel.stageItems) { stage in
                        Image(stage.imageName)
                            .resizable()
                            .scaledToFill()
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.72)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                            .clipped()
                    }
                }
            }
        }
        .frame(height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if let stage = activeStage {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.nameId.localizedFromSplatNet)
                        .font(.appHeadline)
                        .foregroundStyle(.white)
                    Text("x\(stage.count)")
                        .font(.appMono)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func playerSection(
        title: String,
        players: [BattleShiftDetailViewModel.PlayerEncounter],
        accent: Color
    ) -> some View {
        if !players.isEmpty {
            ModeDetailSection(
                title: title,
                trailing: "\(players.count) 人",
                accent: accent
            ) {
                ModeDetailCard {
                    VStack(spacing: 6) {
                        ForEach(players) { encounter in
                            BattleShiftEncounterPlayerRow(encounter: encounter)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    activePlayer = encounter.representative
                                    showPlayerSkill = true
                                }
                        }
                    }
                }
            }
        }
    }

    private var activeStage: BattleShiftDetailViewModel.StageItem? {
        guard !viewModel.stageItems.isEmpty else { return nil }
        return viewModel.stageItems[min(activeStageIndex, viewModel.stageItems.count - 1)]
    }

    private var maxRuleCount: Int {
        viewModel.summary.ruleBuckets.map(\.count).max() ?? 1
    }

    private var timeSpanText: String {
        guard let status = viewModel.status else { return "" }
        return status.startTime.toShiftTimeSpanString(end: status.endTime)
    }

    private func makeShareSummary() -> String {
        "【imink 对战班次】\(battleMode.name) (\(timeSpanText)) | 共 \(viewModel.summary.totalCount) 场：\(viewModel.summary.winCount)胜 \(viewModel.summary.loseCount)负 | KD \(String(format: "%.2f", viewModel.summary.kd)) (KA/D \(String(format: "%.2f", viewModel.summary.kad)))"
    }
}
