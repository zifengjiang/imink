import SwiftUI
import UIKit
import SplatDatabase

struct BattleDetailView: View {
    @State var phase: Double = 0
    @StateObject var viewModel: BattleDetailViewModel

    @State private var myselfPosition: CGFloat = 0
    @State private var hidePlayerNames: Bool = false
    @State private var showPlayerSkill: Bool = false
    @State private var activePlayer: Player? = nil
    @State private var activePlayerVictory: Bool = false
    @State private var hoveredMember: Bool = false

    init(id: Int64) {
        _viewModel = StateObject(wrappedValue: BattleDetailViewModel(id: id))
    }

    var winTeam: [VsTeam] {
        viewModel.battle?.teams.filter { $0.judgement == "WIN" || $0.order == 1 } ?? []
    }

    var loseTeam: [VsTeam] {
        viewModel.battle?.teams.filter { $0.judgement == "LOSE" } ?? []
    }

    private var myPlayer: Player? {
        viewModel.battle?.teams
            .flatMap(\.players)
            .first(where: { $0.isMyself == true })
    }

    var body: some View {
        Group {
            if !viewModel.initialized {
                LoadingView(size: 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fixSafeareaBackground()
            } else if let battle = viewModel.battle {
                let mode = BattleMode(rawValue: battle.mode)
                let rule = BattleRule(rawValue: battle.rule)
                let stage = battle.stage

                ModeDetailScaffold(
                    header: makeHeader(battle: battle, mode: mode, rule: rule, stage: stage),
                    metrics: makeMetrics(battle: battle, mode: mode),
                    shareSummary: makeShareSummary(battle: battle, mode: mode, rule: rule, stage: stage)
                ) {
                    heroStageView(battle: battle, rule: rule, stage: stage)
                } bodyContent: {
                    winTeamSections(rule: rule)
                    loseTeamSections(rule: rule)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("未找到该对战记录")
                        .font(.appHeadline)
                        .foregroundStyle(.appLabel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .fixSafeareaBackground()
            }
        }
        .navigationTitle("对战详情")
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

    // MARK: - Fallback Labels

    private func resolvedModeLabel(battle: Battle, mode: BattleMode?) -> String {
        if let mode { return mode.name }
        return battle.mode.isEmpty ? "未知模式" : battle.mode
    }

    private func resolvedRuleLabel(battle: Battle, rule: BattleRule?) -> String {
        if let rule { return rule.name }
        return battle.rule.isEmpty ? "未知规则" : battle.rule
    }

    private func resolvedStageLabel(battle: Battle, stage: ImageMap?) -> String {
        if let stage {
            if !stage.nameId.isEmpty {
                let localized = stage.nameId.localizedFromSplatNet
                if !localized.isEmpty {
                    return localized
                }
            }
            if !stage.name.isEmpty {
                return stage.name
            }
        }
        return "场地 #\(battle.stageId)"
    }

    // MARK: - Header & Metrics

    private func makeHeader(
        battle: Battle,
        mode: BattleMode?,
        rule: BattleRule?,
        stage: ImageMap?
    ) -> ModeDetailHeaderConfig {
        let isWin = battle.judgement == "WIN"
        let isLose = battle.judgement.contains("LOSE")
        let stamp: String = {
            if isWin {
                return battle.knockout == "WIN" ? "VICTORY · KO" : "VICTORY"
            } else if battle.judgement == "DEEMED_LOSE" {
                return "DEEMED LOSE"
            } else if isLose {
                return "DEFEAT"
            } else if battle.judgement == "DRAW" {
                return "DRAW"
            } else {
                return battle.judgement
            }
        }()
        let stampColor: Color = isWin ? .spLightGreen : (isLose ? .spPink : .spYellow)

        var metaParts: [String] = []
        if let udemae = battle.udemae, !udemae.isEmpty {
            if let pt = battle.earnedUdemaePoint {
                metaParts.append("\(udemae) +\(pt)p")
            } else {
                metaParts.append(udemae)
            }
        }
        if let xPower = battle.lastXPower, xPower > 0 {
            metaParts.append(String(format: "XP %.1f", xPower))
        } else if let leaguePower = battle.myLeaguePower, leaguePower > 0 {
            metaParts.append("LP \(leaguePower)")
        } else if let festContribution = battle.festContribution, festContribution > 0 {
            metaParts.append("贡献 \(festContribution)")
        }
        metaParts.append("\(battle.duration)s")

        let modeName = resolvedModeLabel(battle: battle, mode: mode)
        let ruleName = resolvedRuleLabel(battle: battle, rule: rule)
        let stageName = resolvedStageLabel(battle: battle, stage: stage)

        return ModeDetailHeaderConfig(
            modeBadge: modeName,
            title: "\(ruleName) · \(stageName)",
            subtitle: battle.playedTime.toPlayedTimeString(full: true),
            accent: mode?.color ?? .spOrange,
            icon: mode?.icon ?? Image(systemName: "flag.2.crossed.fill"),
            resultText: stamp,
            resultColor: stampColor,
            resultSubtext: metaParts.joined(separator: " · ")
        )
    }

    private func makeMetrics(battle: Battle, mode: BattleMode?) -> [ModeDetailMetric] {
        let kill = myPlayer?.kill ?? 0
        let assist = myPlayer?.assist ?? 0
        let death = myPlayer?.death ?? 0
        let special = myPlayer?.special ?? 0
        let paint = myPlayer?.paint ?? 0
        let kdValue = Double(kill) / Double(max(death, 1))

        return [
            ModeDetailMetric(
                id: "kill",
                label: "击倒",
                value: "\(kill)",
                unit: assist > 0 ? "+\(assist)助" : nil,
                valueColor: .spLightGreen
            ),
            ModeDetailMetric(
                id: "death",
                label: "阵亡 / 大招",
                value: "\(death)",
                unit: "· \(special)SP"
            ),
            ModeDetailMetric(
                id: "kd",
                label: "KD",
                value: String(format: "%.2f", kdValue),
                valueColor: mode?.color ?? .spOrange
            ),
            ModeDetailMetric(
                id: "paint",
                label: "涂墨",
                value: "\(paint)",
                unit: "p"
            )
        ]
    }

    private func heroStageView(battle: Battle, rule: BattleRule?, stage: ImageMap?) -> some View {
        let hasStageAsset: Bool = {
            guard let name = stage?.name, !name.isEmpty else { return false }
            return UIImage(named: name) != nil
        }()

        return Group {
            if hasStageAsset, let stage {
                Image(stage.name)
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.65), Color.black.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(resolvedStageLabel(battle: battle, stage: stage))
                            .font(.appBody)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.bottom, 26)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topLeading) {
            if rule == .triColor {
                FestIcon(colors: battle.getColors())
                    .frame(width: 28, height: 28)
                    .padding(6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if battle.judgement == "DEEMED_LOSE" {
                Text("对战未能正常结束")
                    .font(.appCaption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.spPink.opacity(0.88), in: Capsule())
                    .padding(8)
            }
        }
        .overlay(alignment: .bottom) {
            BattleWaveOverlay(crt: battle.getColorRatioText())
        }
    }

    // MARK: - Team Sections

    private func winTeamSections(rule: BattleRule?) -> some View {
        ForEach(winTeam.indices, id: \.self) { index in
            let team = winTeam[index]
            ModeDetailSection(
                title: "胜利队伍",
                trailing: teamScoreText(team: team, rule: rule),
                accent: team.color.toColor()
            ) {
                BattleTeamList(
                    team: team,
                    activePlayer: $activePlayer,
                    showPlayerSkill: $showPlayerSkill,
                    hoveredMember: $hoveredMember
                )
            }
        }
    }

    private func loseTeamSections(rule: BattleRule?) -> some View {
        ForEach(loseTeam.indices, id: \.self) { index in
            let team = loseTeam[index]
            ModeDetailSection(
                title: "落败队伍",
                trailing: teamScoreText(team: team, rule: rule),
                accent: team.color.toColor()
            ) {
                BattleTeamList(
                    team: team,
                    activePlayer: $activePlayer,
                    showPlayerSkill: $showPlayerSkill,
                    hoveredMember: $hoveredMember
                )
            }
        }
    }

    private func teamScoreText(team: VsTeam, rule: BattleRule?) -> String? {
        if rule == .turfWar || rule == .triColor {
            if let ratio = team.paintRatio {
                return String(format: "%.1f%%", ratio * 100)
            }
        }
        if let score = team.score {
            return "\(score) 计数"
        }
        if let ratio = team.paintRatio {
            return String(format: "%.1f%%", ratio * 100)
        }
        return nil
    }

    private func makeShareSummary(
        battle: Battle,
        mode: BattleMode?,
        rule: BattleRule?,
        stage: ImageMap?
    ) -> String {
        let kill = myPlayer?.kill ?? 0
        let assist = myPlayer?.assist ?? 0
        let death = myPlayer?.death ?? 0
        let paint = myPlayer?.paint ?? 0
        let result = battle.judgement == "WIN" ? "胜利" : (battle.judgement.contains("LOSE") ? "落败" : "平局")
        let modeName = resolvedModeLabel(battle: battle, mode: mode)
        let ruleName = resolvedRuleLabel(battle: battle, rule: rule)
        let stageName = resolvedStageLabel(battle: battle, stage: stage)
        return "【imink 对战战报】\(modeName) · \(ruleName) | \(stageName) | \(result) | 击倒 \(kill)(\(assist)助) / 阵亡 \(death) | 涂墨 \(paint)p | \(battle.playedTime.toPlayedTimeString(full: true))"
    }
}
