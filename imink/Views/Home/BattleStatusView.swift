import SwiftUI
import SplatDatabase
import Charts

struct BattleStatusView: View {

    let today: BattleGroupStatus

    @AppStorage("showKDInHome")
    private var showKD: Bool = false

    var body: some View {
        HStack(spacing: 8) {

            VStack {
                HStack {

                    Chart {
                        SectorMark(angle: .value("1", today.disconnectCount))
                            .foregroundStyle(Color.gray)
                        SectorMark(angle: .value("2", today.loseCount))
                            .foregroundStyle(Color.waveDefeat)
                        SectorMark(angle: .value("3", today.winCount))
                            .foregroundStyle(Color.waveClear)
                    }
                    .opacity(0.9)
                    .frame(width: 25, height: 25)

                    Text("胜率")
                        .font(.appBody)
                        .foregroundStyle(.appLabel)
                        .minimumScaleFactor(0.5)

                    Text("\(today.victoryRate*100, places: 1)%")
                        .font(.appBodyMono)
                        .foregroundStyle(.secondary)

                }

                HStack {

                    Spacer()

                    VStack(spacing: 4) {

                        Text("胜利")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        Text("\(today.winCount)")
                            .font(.appGameMetric(size: 24))
                            .foregroundStyle(.waveClear)
                            .minimumScaleFactor(0.5)


                    }

                    Spacer()

                    VStack(spacing: 4) {

                        Text("失败")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        Text("\(today.loseCount)")
                            .font(.appGameMetric(size: 24))
                            .foregroundStyle(Color.pink.opacity(0.8))
                            .minimumScaleFactor(0.5)

                    }

                    Spacer()

                    VStack(spacing: 4) {

                        Text("平局")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        Text("\(today.drawCount)")
                            .font(.appGameMetric(size: 24))
                            .foregroundStyle(Color.pink.opacity(0.8))
                            .minimumScaleFactor(0.5)

                    }

                    Spacer()

                    VStack(spacing: 4) {

                        Text("掉线")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)

                        Text("\(today.disconnectCount)")
                            .font(.appGameMetric(size: 24))
                            .foregroundStyle(Color.pink.opacity(0.8))
                            .minimumScaleFactor(0.5)

                    }


                    Spacer()

                }
            }
            .padding([.top,.bottom],5)
            .background(.listItemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            ZStack {
                VStack {
                    HStack {

                        if showKD {

                            Chart {
                                SectorMark(angle: .value("1", today.kill))
                                    .foregroundStyle(Color.red)
                                SectorMark(angle: .value("2", today.death))
                                    .foregroundStyle(Color.gray.opacity(0.5))

                            }
                            .opacity(0.9)
                            .frame(width: 25, height: 25)

                            Text("K/D:")
                                .font(.appBody)
                                .foregroundStyle(.appLabel)

                            Text("\(today.kd, places: 1)")
                                .font(.appBodyMono)
                                .foregroundStyle(.secondary)
                        } else {

                            Chart {
                                SectorMark(angle: .value("1", today.kill))
                                    .foregroundStyle(Color.red)
                                SectorMark(angle: .value("2", today.assist))
                                    .foregroundStyle(Color.red.opacity(0.8))
                                SectorMark(angle: .value("3", today.death))
                                    .foregroundStyle(Color.gray.opacity(0.5))
                            }
                            .opacity(0.9)
                            .frame(width: 25, height: 25)

                            Text("KA/D:")
                                .font(.appBody)
                                .foregroundStyle(.appLabel)

                            Text("\(today.kad, places: 1)")
                                .font(.appBodyMono)
                                .foregroundStyle(.secondary)
                        }

                    }

                    HStack {

                        Spacer()

                        VStack(spacing: 4) {

                            if showKD {
                                Text("KILL")
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)

                                Text("\(today.kill)")
                                    .font(.appGameMetric(size: 24))
                                    .foregroundStyle(.red)
                                    .minimumScaleFactor(0.5)
                            } else {
                                Text("KILL+ASSIST")
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)

                                Text("\(today.kill + today.assist)")
                                    .font(.appGameMetric(size: 24))
                                    .foregroundStyle(.red)
                                    .minimumScaleFactor(0.5)
                            }

                        }

                        Spacer()

                        VStack(spacing: 4) {

                            Text("DEATH")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)

                            Text("\(today.death)")
                                .font(.appGameMetric(size: 24))
                                .foregroundStyle(.gray.opacity(0.5))
                                .minimumScaleFactor(0.5)

                        }

                        Spacer()

                    }
                }
                .padding([.top,.bottom],5)
                .background(.listItemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack {
                    HStack {
                        Spacer()

                        Image(systemName: showKD ? "circle" : "largecircle.fill.circle")
                            .resizable()
                            .frame(width: 14, height: 14)
                            .foregroundColor(Color.gray.opacity(0.3))
                            .padding([.trailing, .top], 6)
                    }

                    Spacer()
                }
            }
            .onTapGesture {
                showKD.toggle()
            }

        }
        .frame(maxWidth: .infinity)

    }
}
