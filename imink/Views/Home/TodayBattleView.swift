//
//  TodayBattleView.swift
//  imink
//
//  Created by 姜锋 on 10/3/24.
//

import Foundation
import SwiftUI
import Charts

struct TodayBattleView: View {

    let today: BattleGroupStatus

    @AppStorage("showKDInHome")
    private var showKD: Bool = false

    var body: some View {
        HStack(spacing: 8) {

            VStack {
                HStack {

                    Chart {
                        SectorMark(angle: .value("1", today.disconnect))
                            .foregroundStyle(Color.gray)
                        SectorMark(angle: .value("2", today.defeat))
                            .foregroundStyle(Color.waveDefeat)
                        SectorMark(angle: .value("3", today.victory))
                            .foregroundStyle(Color.waveClear)
                    }
                    .opacity(0.9)
                    .frame(width: 25, height: 25)

                    Text("胜率")
                        .font(.splatoonFont(size: 16))
                        .foregroundStyle(.appLabel)
                        .minimumScaleFactor(0.5)

                    Text("\(today.victoryRate.rounded()*100)%")
                        .font(.splatoonFont(size: 16))
                        .foregroundStyle(.secondary)

                }

                HStack {

                    Spacer()

                    VStack(spacing: 4) {

                        Text("胜利")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)

                        Text("\(today.victory)")
                            .font(.splatoonFont(size: 24))
                            .foregroundStyle(.waveClear)
                            .minimumScaleFactor(0.5)


                    }

                    Spacer()

                    VStack(spacing: 4) {

                        Text("失利")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)

                        Text("\(today.defeat)")
                            .font(.splatoonFont(size: 24))
                            .foregroundStyle(.waveDefeat)
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
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.appLabel)

                            Text("\(today.kd, places: 1)")
                                .font(.splatoonFont(size: 16))
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
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.appLabel)

                            Text("\(today.kad, places: 1)")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.secondary)
                        }

                    }

                    HStack {

                        Spacer()

                        VStack(spacing: 4) {

                            if showKD {
                                Text("KILL")
                                    .font(.splatoonFont(size: 10))
                                    .foregroundStyle(.secondary)

                                Text("\(today.kill)")
                                    .font(.splatoonFont(size: 24))
                                    .foregroundStyle(.red)
                                    .minimumScaleFactor(0.5)
                            } else {
                                Text("KILL+ASSIST")
                                    .font(.splatoonFont(size: 10))
                                    .foregroundStyle(.secondary)

                                Text("\(today.kill + today.assist)")
                                    .font(.splatoonFont(size: 24))
                                    .foregroundStyle(.red)
                                    .minimumScaleFactor(0.5)
                            }

                        }

                        Spacer()

                        VStack(spacing: 4) {

                            Text("DEATH")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)

                            Text("\(today.death)")
                                .font(.splatoonFont(size: 24))
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




struct TodayBattle {
    var victoryCount: Int = 0
    var defeatedCount: Int = 0
    var killCount: Int = 0
    var assistCount: Int = 0
    var deathCount: Int = 0
    var disconnect: Int = 0
}
