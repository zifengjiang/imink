import SwiftUI
import SplatDatabase

struct CoopDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: CoopListViewModel

    @State var phase: Double = 0
    @StateObject var viewModel: CoopDetailViewModel
    @State private var showPlayerDetail: Bool = false
    @State private var activePlayer: CoopPlayerResult? = nil
    @State private var hoveredMember: Bool = false
    @Binding var navigationPath: NavigationPath

    var id: Int64

    init(id: Int64, navigationPath: Binding<NavigationPath>) {
        self.id = id
        self._navigationPath = navigationPath
        if let model = AppState.shared.viewModelDict[id] {
            _viewModel = StateObject(wrappedValue: model)
        } else {
            let model = CoopDetailViewModel(id: id)
            _viewModel = StateObject(wrappedValue: model)
        }
    }

    var dangerRateText: String {
        if let dangerRate = viewModel.coop?.dangerRate {
            if dangerRate >= 3.33 {
                return "MAX!!"
            }
            return "\(Int(dangerRate * 100))%"
        }
        return ""
    }

    var body: some View {
        Group {
            if viewModel.initialized, let coop = viewModel.coop {
                ModeDetailScaffold(
                    header: makeHeader(coop: coop),
                    metrics: makeMetrics(coop: coop),
                    shareSummary: makeShareSummary(coop: coop)
                ) {
                    makeCardView()
                } bodyContent: {
                    if !viewModel.waveResults.isEmpty {
                        ModeDetailSection(
                            title: "波次进展",
                            trailing: "\(viewModel.waveResults.count) 波",
                            accent: .salmonRunTheme
                        ) {
                            waveView
                        }
                    }

                    if !viewModel.playerResults.isEmpty {
                        ModeDetailSection(
                            title: "参与工友",
                            trailing: "\(viewModel.playerResults.count) 人",
                            accent: .spGreen
                        ) {
                            memberView
                        }
                    }

                    if !viewModel.enemyResults.isEmpty {
                        ModeDetailSection(
                            title: "巨大鲑鱼",
                            trailing: bossTrailingSummary,
                            accent: .spOrange
                        ) {
                            enemyView
                        }
                    }
                }
            } else {
                LoadingView(size: 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fixSafeareaBackground()
            }
        }
        .navigationTitle("打工详情")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(Popup(
            isPresented: showPlayerDetail,
            onDismiss: {
                showPlayerDetail = false
            },
            content: {
                CoopPlayerView(result: activePlayer, onViewPlayerRecords: { playerName, playerByname, playerNameId in
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
        .onAppear {
            AppState.shared.viewModelDict[self.id] = viewModel
            if !viewModel.initialized {
                viewModel.load()
            }
        }
        .onDisappear {
            AppState.shared.viewModelDict.removeValue(forKey: self.id)
        }
    }

    // MARK: - Header & Metrics

    private func makeHeader(coop: Coop) -> ModeDetailHeaderConfig {
        let rule = CoopRule(rawValue: coop.rule) ?? .REGULAR
        let gradeSubtext: String = {
            if let gradeName = coop.gradeName, let gradePoint = coop.afterGradePoint {
                return "\(gradeName.localizedFromSplatNet) \(gradePoint)"
            }
            return "危险度 \(dangerRateText)"
        }()

        return ModeDetailHeaderConfig(
            modeBadge: rule.name,
            title: coop.stageName?.localizedFromSplatNet ?? rule.name,
            subtitle: coop.playedTime.toPlayedTimeString(full: true),
            accent: .salmonRunTheme,
            icon: rule.icon,
            resultText: coop.clear ? "Clear!!" : "Failure",
            resultColor: coop.clear ? .waveClear : .waveDefeat,
            resultSubtext: gradeSubtext
        )
    }

    private func makeMetrics(coop: Coop) -> [ModeDetailMetric] {
        let dangerValue: String
        let dangerUnit: String?
        if coop.dangerRate >= 3.33 {
            dangerValue = "MAX!!"
            dangerUnit = nil
        } else {
            dangerValue = "\(Int(coop.dangerRate * 100))"
            dangerUnit = "%"
        }

        return [
            ModeDetailMetric(
                id: "goldenEgg",
                label: "金鲑鱼卵",
                value: "\(coop.egg)",
                unit: "粒",
                valueColor: .spYellow
            ),
            ModeDetailMetric(
                id: "powerEgg",
                label: "普通鲑鱼卵",
                value: "\(coop.powerEgg)",
                unit: "粒"
            ),
            ModeDetailMetric(
                id: "dangerRate",
                label: "危险度",
                value: dangerValue,
                unit: dangerUnit,
                valueColor: .salmonRunTheme
            ),
            ModeDetailMetric(
                id: "jobPoint",
                label: "获得点数",
                value: "\(coop.jobPoint ?? 0)",
                unit: "p",
                valueColor: .waveClear
            )
        ]
    }

    private var bossTrailingSummary: String {
        let regularBosses = viewModel.enemyResults.filter { !$0.isBoss }
        let totalPop = regularBosses.reduce(0) { $0 + $1.popCount }
        let totalDefeat = regularBosses.reduce(0) { $0 + (Int($1.teamDefeatCount) ?? 0) }
        guard totalPop > 0 else { return "" }
        return "击倒 \(totalDefeat)/\(totalPop)"
    }

    private func makeShareSummary(coop: Coop) -> String {
        let rule = CoopRule(rawValue: coop.rule) ?? .REGULAR
        let stage = coop.stageName?.localizedFromSplatNet ?? rule.name
        let status = coop.clear ? "Clear!!" : "Failure"
        return "【imink 打工战报】\(rule.name) · \(stage) | \(status) | 金蛋 \(coop.egg) · 红蛋 \(coop.powerEgg) | 危险度 \(dangerRateText) | 获得 \(coop.jobPoint ?? 0)p | \(coop.playedTime.toPlayedTimeString(full: true))"
    }

    // MARK: - Subsections

    var cardView: some View {
        makeCardView()
    }

    var waveView: some View {
        ModeDetailCard {
            VStack(spacing: 12) {
                if let coop = viewModel.coop {
                    if coop.rule == "TEAM_CONTEST" && viewModel.waveResults.count > 4 {
                        waveResultsView(range: 0..<3)
                        waveResultsView(range: 3..<5)
                    } else {
                        waveResultsView(range: viewModel.waveResults.indices)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    var memberView: some View {
        ModeDetailCard {
            VStack(spacing: 8) {
                ForEach(viewModel.playerResults.indices, id: \.self) { i in
                    if i != 0 {
                        Divider()
                    }
                    CoopDetailMemberView(
                        result: viewModel.playerResults[i],
                        activePlayer: $activePlayer,
                        showPlayerDetail: $showPlayerDetail,
                        hoveredMember: $hoveredMember
                    )
                }
            }
        }
    }

    var enemyView: some View {
        ModeDetailCard {
            VStack(spacing: 8) {
                let kings = viewModel.enemyResults.filter(\.isBoss)
                if !kings.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(kings.indices, id: \.self) { idx in
                            let king = kings[idx]
                            HStack(spacing: 10) {
                                Image(king.enemyImage ?? "DummyEnemy")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(king.enemyName?.localizedFromSplatNet ?? "头目联合")
                                        .font(.appBody)
                                        .foregroundStyle(.appLabel)
                                    Text(king.defeatCount == 1 ? "成功击倒！" : "未能击倒...")
                                        .font(.appCaption)
                                        .foregroundStyle(king.defeatCount == 1 ? Color.waveClear : Color.waveDefeat)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.listBackground.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                let regularEnemies = viewModel.enemyResults.filter { !$0.isBoss }
                ForEach(regularEnemies.indices, id: \.self) { i in
                    if i != 0 {
                        Divider()
                    }
                    makeEnemyView(result: regularEnemies[i])
                }
            }
        }
    }
}
