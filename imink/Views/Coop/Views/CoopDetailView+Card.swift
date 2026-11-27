import SwiftUI
import SplatDatabase

extension CoopDetailView {
    func makeCardView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let coop = viewModel.coop {
                if let stageImage = coop.stageImage {
                    Image(stageImage)
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
                        .overlay(alignment: .topTrailing) {
                            if let smellMeter = coop.smellMeter, let bossName = coop.bossName {
                                SineWaveShape(
                                    percent: 1 - Double(smellMeter) * 0.2,
                                    strength: 1.2,
                                    frequency: 12,
                                    phase: self.phase,
                                    totalWidth: 44
                                )
                                .fill(Color.salmonRunTheme)
                                .animation(Animation.linear(duration: 3).repeatForever(autoreverses: false), value: self.phase)
                                .onAppear {
                                    phase = .pi * 2
                                }
                                .frame(width: 44, height: 44)
                                .background(Color.battleDetailStreakForeground)
                                .mask {
                                    Image(bossName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 44, height: 44)
                                        .colorMultiply(.black)
                                }
                                .padding(6)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .padding(8)
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
                            HStack(spacing: 8) {
                                if let suppliedWeapons = coop.suppliedWeapons {
                                    HStack(spacing: 6) {
                                        ForEach(suppliedWeapons.indices, id: \.self) { i in
                                            Image(suppliedWeapons[i])
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

                                Text("危险度 \(dangerRateText)")
                                    .font(.appCaptionMono)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.62), in: Capsule())
                            }
                            .padding(10)
                        }
                }

                // 结算公式与鳞片/评价条（保留原卡片全部数值，整理进统一 4pt 栅格）
                HStack(alignment: .center, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        metricPair(value: "\(coop.jobScore ?? 0)", label: "job_score".localized)
                        Text("×")
                            .font(.appCaptionMono)
                            .foregroundStyle(.secondary)
                        metricPair(value: "\(coop.jobRate ?? 0, places: 2)", label: "pay_grade".localized)
                        Text("+")
                            .font(.appCaptionMono)
                            .foregroundStyle(.secondary)
                        metricPair(value: "\(coop.jobBonus ?? 0)", label: "clear_bonus".localized)
                    }

                    Spacer(minLength: 8)

                    if coop.rule != CoopRule.TEAM_CONTEST.rawValue {
                        VStack(alignment: .trailing, spacing: 4) {
                            if let gradeName = coop.gradeName, let gradePoint = coop.afterGradePoint {
                                HStack(spacing: 6) {
                                    Text("\(gradeName.localizedFromSplatNet) \(gradePoint)")
                                        .font(.appCaptionMono)
                                        .foregroundStyle(Color.waveClear)
                                    ProgressBar(fillPercentage: gradePoint >= 100 ? 1 : Double(gradePoint) / 100.0)
                                        .frame(width: 56)
                                }
                            }

                            HStack(spacing: 8) {
                                let scaleIcons: [Image] = [Image(.urocoIcon00), Image(.urocoIcon01), Image(.urocoIcon02)]
                                let scales: [String] = coop.goldScale != nil
                                    ? ["\(coop.goldScale ?? 0)", "\(coop.silverScale ?? 0)", "\(coop.bronzeScale ?? 0)"]
                                    : ["-", "-", "-"]
                                ForEach(0..<3, id: \.self) { i in
                                    HStack(spacing: 2) {
                                        scaleIcons[i]
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 15, height: 15)
                                        Text(scales[i])
                                            .font(.appCaptionMono)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func metricPair(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.appMono)
                .foregroundStyle(.appLabel)
            Text(label)
                .font(.appSubCaptionMono)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
