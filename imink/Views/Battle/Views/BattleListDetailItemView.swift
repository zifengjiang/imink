//
//  BattleListDetailItemView.swift
//  imink
//
//  Created by 姜锋 on 2025/8/16.
//

import SwiftUI

struct BattleListDetailItemView: View {
    let detail:BattleListRowInfo
    var mode:BattleMode{detail.mode}
    var rule:BattleRule{detail.rule}
    var species:Species{detail.species ? Species.INKLING : Species.OCTOLING}
    var ratios:[Double]{
        let r = getRatio(scores: detail.scores, ratios: detail.ratios, count: detail.colors.count)
        var res = [Double]()
        _ = r.reduce(0){ sum, cur in
            let newSum = sum + cur
            res.append(newSum)
            return newSum
        }
        return res
    }

    var body: some View {
        ZStack {
            VStack(spacing:0){
                HStack(spacing:6){
                    if mode == .fest{
                        FestIcon()
                            .frame(width: 16, height: 16)
                            .padding(.top, -0.5)
                            .padding(.bottom, -1.5)
                    }else{
                        mode.icon
                            .resizable()
                            .frame(width: 16, height: 16)
                            .padding(.top, -0.5)
                            .padding(.bottom, -1.5)
                    }

                    Text(rule.name)
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(mode.color)
                    Spacer()

                    if mode == .anarchy{
                        HStack(alignment: .firstTextBaseline, spacing: 0){
                            Text(detail.udemae ?? "C-")
                                .font(.splatoonFont(size: 12))
                            if let plus = detail.earnedUdemaePoint{
                                Text("\(plus)")
                                    .font(.splatoonFont(size: 8))
                                    .padding(.leading,0.6)
                                    //                  .padding(.bottom, 0)
                            }
                        }
                    }
                }
                .padding(.bottom, 6.5)

                HStack {
                    Text(detail.judgement.name)
                        .font(.splatoonFont(size: 14))
                        .foregroundStyle(detail.judgement.color)
                    if let k = detail.knockout, k == .WIN {
                        Text("完胜!")
                            .font(.splatoonFont(size: 14))
                            .foregroundStyle(.spYellow)
                    }else if rule != .turfWar && rule != .triColor{
                        Text("\(detail.point)计数")
                            .font(.splatoonFont(size: 14))
                            .foregroundStyle(detail.judgement == .LOSE ? Color.secondary : .spGreen)
                    }else {
                        Text("\(detail.point)p")
                            .font(.splatoonFont(size: 14))
                            .foregroundStyle(detail.judgement == .LOSE ? Color.secondary : .spGreen)
                    }
                    Spacer()
                    HStack{
                        HStack(spacing:3){
                            species.icon.kill
                                .resizable()
                                .frame(width: 14, height: 14)
                                .foregroundColor(.gray)
                            HStack(alignment: .firstTextBaseline, spacing: 0){
                                Text("\((detail.kill) + (detail.assist))")
                                    .font(.splatoonFont(size: 10))
                                Text("(\(detail.assist))")
                                    .font(.splatoonFont(size: 7))
                            }
                        }

                        HStack(spacing: 3) {
                            species.icon.dead
                                .resizable()
                                .frame(width: 14, height: 14)
                                .foregroundColor(.gray)
                            Text("\(detail.death)")
                                .font(.splatoonFont(size: 10))
                        }

                        HStack(spacing: 3) {
                            species.icon.kd
                                .resizable()
                                .frame(width: 14, height: 14)
                                .foregroundColor(.gray)
                            let death = detail.death
                            Text("\(Double(detail.kill) -/ Double(death == 0 ? 1 : death), places: 1)")
                                .font(.splatoonFont(size: 10))
                        }
                    }
                }
                .padding(.bottom, 7)

                HStack(spacing: 0) {
                    GeometryReader { geo in
                        Rectangle()
                            .foregroundStyle(Color.gray)
                            //                        Rectangle()
                            //                            .foregroundColor(detail.judgement.color)
                            //                            .frame(width: geo.size.width*myPoint)
                        ForEach(ratios.indices.reversed(), id: \.self){ index in
                            Rectangle()
                                .foregroundColor(detail.colors[index].toColor())
                                .frame(width: geo.size.width*ratios[index])
                        }


                    }
                }
                .frame(height: 5)
                .clipShape(Capsule())
                .padding(.bottom, 6)

                HStack{
                    Text(detail.stage.localizedFromSplatNet)
                        .font(.splatoonFont(size: 10))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text(detail.playedTime.toPlayedTimeString(full: true))
                        .font(.splatoonFont(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }


            VStack {
                if let weapon = detail._weapon{
                    Image(weapon.mainWeapon.name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
            .padding(.top, 6.5)
        }
        .padding(.top, 7.5)
        .padding(.bottom, 7)
        .padding([.leading, .trailing], 8)
        .background(Color(.listItemBackground))
        .frame(height: 85)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding([.leading, .trailing])
        .padding(.top,3)
    }
}

//#Preview {
//    BattleListDetailItemView()
//}
