//
//  BattleListShiftCardView.swift
//  imink
//
//  Created by 姜锋 on 2025/8/16.
//

import SwiftUI

struct BattleListShiftCardView: View {
    let status: BattleGroupStatus

    var body: some View {
        ShiftCardChrome(
            count: status.count,
            unit: "场对战",
            disconnectCount: status.disconnectCount
        ) {
            VStack{
                HStack{
                    Text(status.startTime.toShiftTimeSpanString(end: status.endTime))
                        .font(.splatoonFont(size: 12))
                    Spacer()
                    Text(status.mode.localized)
                        .font(.splatoonFont(size: 10))
                        .foregroundStyle(.secondary)
                }
                HStack {

                    StatusView(status: status)

                    Spacer()

                    // 显示对战模式图标
                    BattleMode(rawValue: status.mode)?.icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .padding([.leading, .trailing], 10)
                        .padding([.top, .bottom], 6)
                        .background(Color(.sRGB, white: 151 / 255.0, opacity: 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                }
            }
        }
    }

    struct StatusView: View {
        let status: BattleGroupStatus
        var hSpace: CGFloat = 5
        var vSpace: CGFloat = 8
        
        var body: some View {
            VStack(alignment: .leading, spacing: vSpace){
                HStack(spacing: hSpace){
                    HStack(spacing: 3){
                        Image(.turfWar)
                            .resizable()
                            .bold()
                            .foregroundStyle(Color.green)
                            .frame(width: 12, height: 12)
                        Text("\(status.victoryRate, places: 1)")
                            .font(.splatoonFont(size: 12))
                    }
                    .frame(width: 45, alignment: .leading)

                    HStack(spacing: 3){
                        Image(.anarchy)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(status.kd, places: 1)")
                            .font(.splatoonFont(size: 12)) + Text("<\(status.kad, places: 1)>")
                            .font(.splatoonFont(size: 9)).foregroundColor(.secondary)
                    }
                }

                HStack(spacing: hSpace){
                    HStack(spacing: 3){
                        Image(.xBattle)
                            .resizable()
                            .bold()
                            .foregroundStyle(Color.green)
                            .frame(width: 12, height: 12)
                        Text("\(status.winCount)")
                            .font(.splatoonFont(size: 12))
                    }
                    .frame(width: 45, alignment: .leading)

                    HStack(spacing: 3){
                        Image(.event)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(status.loseCount)")
                            .font(.splatoonFont(size: 12))
                    }
                }
            }
        }
    }
}

//#Preview {
//    BattleListShiftCardView()
//}
