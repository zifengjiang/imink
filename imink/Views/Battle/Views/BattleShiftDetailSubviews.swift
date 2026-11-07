import SwiftUI
import SplatDatabase

struct BattleShiftSummaryMetric: View {
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

struct BattleShiftRuleChartRow: View {
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

struct BattleShiftEncounterPlayerRow: View {
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
                        .animation(
                            Animation.linear(duration: 0.55).repeatForever(autoreverses: true),
                            value: arrowOffset
                        )
                        .onAppear {
                            // 由上面的 .animation(_:value:) 驱动来回摆动
                            arrowOffset = 7
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
