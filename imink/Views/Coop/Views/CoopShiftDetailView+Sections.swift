import SwiftUI
import SplatDatabase

extension CoopShiftDetailView {
    var cardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let coopGroupStatus = viewModel.coopGroupStatus {
                if let stage = coopGroupStatus._stage {
                    Image(stage.name)
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.68)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        )
                        .overlay(alignment: .bottomLeading) {
                            HStack(spacing: 8) {
                                if let suppliedWeapon = coopGroupStatus._suppliedWeapon {
                                    HStack(spacing: 6) {
                                        ForEach(suppliedWeapon.indices, id: \.self) { i in
                                            Image(suppliedWeapon[i].name)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.62), in: Capsule())
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    let scaleImages: [Image] = [Image(.scale1), Image(.scale2), Image(.scale3)]
                                    let scales: [Int] = [coopGroupStatus.bronzeScale, coopGroupStatus.silverScale, coopGroupStatus.goldScale]
                                    ForEach(0..<3, id: \.self) { i in
                                        HStack(spacing: 2) {
                                            scaleImages[i]
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 15, height: 15)
                                            Text("\(scales[i])")
                                                .font(.appCaptionMono)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.62), in: Capsule())
                            }
                            .padding(10)
                        }
                }
            }
        }
    }

    var waveView: some View {
        CarouselView(activeIndex: .constant(1), autoScrollDuration: 5) {
            ForEach(viewModel.coopWaveStatus.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    ForEach(viewModel.coopWaveStatus[index], id: \.waterLevel) { wave in
                        CoopShiftDetailWaveStatusView(result: wave)
                    }
                }
            }
        }
        .frame(height: 120)
    }

    var weaponView: some View {
        ModeDetailCard {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.coopWeaponStatus, id: \.nameId) { weapon in
                    VStack(spacing: 4) {
                        Image(weapon.name)
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                            .frame(width: 38, height: 38)
                            .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("x\(weapon.count)")
                            .font(.appCaptionMono)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    var playerView: some View {
        ModeDetailCard {
            DisclosureGroup {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.coopPlayerStatus.indices, id: \.self) { index in
                        VStack(spacing: 4) {
                            NameplateView(status: viewModel.coopPlayerStatus[index])
                                .overlay {
                                    TouchDownAndTouchUpGestureView {
                                        activePlayer = viewModel.coopPlayerStatus[index]
                                        hoveredMember = true
                                    } touchMovedCallBack: { distance in
                                        if distance > 10 {
                                            hoveredMember = false
                                        }
                                    } touchUpCallBack: {
                                        if hoveredMember {
                                            withAnimation {
                                                showPlayerDetail = true
                                            }
                                            hoveredMember = false
                                        }
                                    }
                                }

                            PlayerEncounterIndicator(playerStatus: viewModel.coopPlayerStatus[index])
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("展开查看遇到过的工友")
                    .font(.appBody)
                    .foregroundStyle(.appLabel)
            }
        }
    }

    var kingView: some View {
        HStack(spacing: 16) {
            let kingSorted = self.viewModel.coopEnemyStatus.filter { $0.nameId.order >= 23 }
            ForEach(kingSorted, id: \.nameId) { king in
                VStack(spacing: 4) {
                    Image(king.name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                    Text("\(king.totalTeamDefeatCount)/\(king.totalPopCount)")
                        .font(.appCaptionMono)
                }
            }
            Spacer(minLength: 0)
        }
    }

    var enemyView: some View {
        ModeDetailCard {
            VStack(spacing: 8) {
                let enemySorted = viewModel.coopEnemyStatus.filter { $0.nameId.order < 23 }
                ForEach(enemySorted, id: \.name) { boss in
                    if boss.name != enemySorted.first?.name {
                        Divider()
                    }
                    HStack {
                        Image(boss.name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                        Text(boss.nameId.localizedFromSplatNet)
                            .font(.appBody)
                        Spacer()

                        Text("\(boss.totalTeamDefeatCount)")
                            .font(.appBodyMono) +
                        Text(boss.totalDefeatCount == 0 ? "" : "(\(boss.totalDefeatCount))")
                            .font(.appCaptionMono)
                        Text("/")
                            .font(.appBodyMono)
                        Text("\("appearances_number".localized)x")
                            .font(.appCaption) +
                        Text("\(boss.totalPopCount)")
                            .font(.appBodyMono)
                    }
                    .frame(height: 40)
                }
            }
        }
    }
}
