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

    var body: some View {
        ScrollView {
            HStack {
                Spacer()
                VStack(spacing: 18) {
                    if viewModel.initialized {
                        summaryCard
                        battleRuleChart
                        weaponsView
                        playerSection(title: "队友", players: viewModel.teammatePlayers)
                        playerSection(title: "对手", players: viewModel.opponentPlayers)
                    } else {
                        LoadingView(size: 100)
                            .padding(.top, 80)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                Spacer()
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .fixSafeareaBackground()
        .navigationTitle("Battle Shift")
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

    private var summaryCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    if let mode = viewModel.status.flatMap({ BattleMode(rawValue: $0.mode) }) {
                        mode.icon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .padding(7)
                            .background(Color.black.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(mode.name)
                            .font(.splatoonFont(size: 18))
                            .foregroundStyle(mode.color)
                    }

                    Spacer()

                    Text(timeSpanText)
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)
                }

                stageCarousel

                HStack(spacing: 8) {
                    SummaryMetric(title: "WIN", value: "\(viewModel.summary.winCount)", color: .spLightGreen)
                    SummaryMetric(title: "LOSE", value: "\(viewModel.summary.loseCount)", color: .spPink)
                    SummaryMetric(title: "DRAW", value: "\(viewModel.summary.drawCount)", color: .spYellow)
                    SummaryMetric(title: "KD", value: "\(viewModel.summary.kd, places: 1)", color: .primary)
                }

                HStack(spacing: 8) {
                    SummaryMetric(title: "地图", value: "\(viewModel.summary.stageCount)", color: .secondary)
                    SummaryMetric(title: "武器", value: "\(viewModel.summary.weaponCount)", color: .secondary)
                    SummaryMetric(title: "K+A/D", value: "\(viewModel.summary.kad, places: 1)", color: .secondary)
                    SummaryMetric(title: "场次", value: "\(viewModel.summary.totalCount)", color: .secondary)
                }
            }
            .padding(14)
            .background(
                GrayscaleTextureView(
                    texture: .bubble,
                    foregroundColor: Color.battleDetailStreakForeground,
                    backgroundColor: Color.listItemBackground
                )
                .frame(height: 420),
                alignment: .topLeading
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack { }
                .frame(maxWidth: .infinity, minHeight: 19, maxHeight: 19)
                .overlay(
                    GrayscaleTextureView(
                        texture: .bubble,
                        foregroundColor: Color.battleDetailStreakForeground,
                        backgroundColor: Color.listItemBackground
                    )
                    .frame(height: 420)
                    .offset(y: -385)
                    .mask(
                        VStack {
                            HStack {
                                Spacer()
                                Image(.jobShiftCardTail)
                                    .resizable()
                                    .frame(width: 33, height: 19)
                            }
                            Spacer()
                        }
                        .padding(.trailing, 28)
                    ),
                    alignment: .topLeading
                )
        }
        .rotationEffect(.degrees(-1))
        .clipped(antialiased: true)
    }

    private var stageCarousel: some View {
        ZStack(alignment: .bottomLeading) {
            if viewModel.stageItems.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.2))
                    .overlay {
                        Text("NO STAGE")
                            .font(.splatoonFont1(size: 20))
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
        .frame(height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if let stage = activeStage {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.nameId.localizedFromSplatNet)
                        .font(.splatoonFont(size: 18))
                        .foregroundStyle(.white)
                    Text("x\(stage.count)")
                        .font(.splatoonFont(size: 13))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(12)
            }
        }
    }

    private var battleRuleChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BATTLE TYPE")
                .font(.splatoonFont1(size: 14))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 10) {
                ForEach(viewModel.summary.ruleBuckets, id: \.rule) { bucket in
                    RuleChartRow(bucket: bucket, maxCount: maxRuleCount)
                }
            }
        }
        .padding(12)
        .textureBackground(texture: .bubble, radius: 16)
    }

    private var weaponsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEAPONS")
                .font(.splatoonFont1(size: 14))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(viewModel.weaponItems) { weapon in
                    VStack(spacing: 4) {
                        Image(weapon.imageName)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                            .frame(height: 48)
                            .background(Color.black.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text("x\(weapon.count)")
                            .font(.splatoonFont(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .textureBackground(texture: .bubble, radius: 16)
    }

    private func playerSection(title: String, players: [BattleShiftDetailViewModel.PlayerEncounter]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.splatoonFont1(size: 16))
                Spacer()
                Text("\(players.count)")
                    .font(.splatoonFont(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 6) {
                ForEach(players) { encounter in
                    EncounterPlayerRow(encounter: encounter)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            activePlayer = encounter.representative
                            showPlayerSkill = true
                        }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.listItemBackground)
            )
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

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        if Calendar.current.component(.year, from: status.startTime) != Calendar.current.component(.year, from: Date()) {
            formatter.dateFormat = "yyyy MM/dd HH:mm"
        }
        return "\(formatter.string(from: status.startTime)) - \(formatter.string(from: status.endTime))"
    }

    private struct SummaryMetric: View {
        let title: String
        let value: String
        let color: Color

        var body: some View {
            VStack(spacing: 2) {
                Text(title)
                    .font(.splatoonFont(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(value)
                    .font(.splatoonFont(size: 17))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Color.black.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private struct RuleChartRow: View {
        let bucket: BattleShiftSummaryBuilder.RuleBucket
        let maxCount: Int

        private var rule: BattleRule? {
            BattleRule(rawValue: bucket.rule)
        }

        var body: some View {
            HStack(spacing: 10) {
                (rule?.image ?? Image(.turfWar))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text(rule?.name ?? bucket.rule)
                    .font(.splatoonFont(size: 13))
                    .frame(width: 92, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.black.opacity(0.18))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.spLightGreen)
                                .frame(width: proxy.size.width * CGFloat(bucket.count) / CGFloat(max(maxCount, 1)))
                        }
                }
                .frame(height: 12)

                Text("\(bucket.count)")
                    .font(.splatoonFont(size: 13))
                    .frame(width: 26, alignment: .trailing)
            }
        }
    }

    private struct EncounterPlayerRow: View {
        let encounter: BattleShiftDetailViewModel.PlayerEncounter
        @StateObject private var viewModel = NameplateViewModel()
        @State private var arrowOffset: CGFloat = 0

        private var player: Player {
            encounter.representative
        }

        private var teamColor: Color {
            Color(red: encounter.color.red, green: encounter.color.green, blue: encounter.color.blue)
        }

        var body: some View {
            HStack(spacing: 9) {
                if let weapon = player._weapon {
                    Image(weapon.mainWeapon.name)
                        .resizable()
                        .scaledToFit()
                        .padding(3)
                        .background(Color.black.opacity(0.75))
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: .infinity, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.formattedByname ?? player.byname)
                        .font(.splatoonFont(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(player.name)
                        .font(.splatoonFont(size: 15))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text("x\(encounter.count)")
                    .font(.splatoonFont(size: 13))
                    .foregroundStyle(teamColor)
                    .frame(width: 38, alignment: .trailing)

                Text("\(encounter.averagePaint)p")
                    .font(.splatoonFont(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)

                kda
            }
            .padding(.vertical, 6)
            .overlay {
                if player.isMyself == true {
                    GeometryReader { geometry in
                        Image(.memberArrow)
                            .foregroundStyle(Color.memberArrow)
                            .position(x: -10, y: geometry.size.height / 2)
                            .offset(x: -arrowOffset)
                            .onAppear {
                                withAnimation(Animation.linear(duration: 0.55).repeatForever(autoreverses: true)) {
                                    arrowOffset = 7
                                }
                            }
                    }
                    .allowsHitTesting(false)
                }
            }
            .task {
                await viewModel._formatByname(byname: player.byname)
            }
        }

        private var kda: some View {
            HStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(encounter.kill)")
                        .font(.splatoonFont(size: 13))
                    Text("<\(encounter.assist)>")
                        .font(.splatoonFont(size: 9))
                        .foregroundStyle(.secondary)
                }

                Text("/\(encounter.death)")
                    .font(.splatoonFont(size: 13))

                if let weapon = player._weapon {
                    SpecialWeaponImage(imageName: weapon.specialWeapon.name, color: teamColor, size: 12)
                    Text("x\(encounter.special)")
                        .font(.splatoonFont(size: 10))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.listBackground)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}
