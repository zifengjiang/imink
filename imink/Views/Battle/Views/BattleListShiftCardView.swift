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
                        .font(.appCaptionMono)
                    Spacer()
                    Text(status.mode.localized)
                        .font(.appCaption)
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
        var hSpace: CGFloat = 8
        var vSpace: CGFloat = 8
        
        var body: some View {
            VStack(alignment: .leading, spacing: vSpace) {
                HStack(spacing: hSpace) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.spLightGreen)
                            .frame(width: 14, height: 14)
                        Text("\(status.victoryRate * 100, places: 1)%")
                            .font(.appMono)
                    }
                    .frame(width: 72, alignment: .leading)

                    HStack(spacing: 4) {
                        Image(systemName: "scope")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.spOrange)
                            .frame(width: 14, height: 14)
                        Text("\(status.kd, places: 1)")
                            .font(.appMono) + Text("<\(status.kad, places: 1)>")
                            .font(.appSubCaptionMono).foregroundColor(.secondary)
                    }
                }

                HStack(spacing: hSpace) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.spLightGreen)
                            .frame(width: 14, height: 14)
                        Text("\(status.winCount)胜")
                            .font(.appMono)
                    }
                    .frame(width: 72, alignment: .leading)

                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.spPink)
                            .frame(width: 14, height: 14)
                        Text("\(status.loseCount)负")
                            .font(.appMono)
                    }
                }
            }
        }
    }
}

//#Preview {
//    BattleListShiftCardView()
//}
