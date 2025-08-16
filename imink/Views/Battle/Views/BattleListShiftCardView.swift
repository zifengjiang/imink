//
//  BattleListShiftCardView.swift
//  imink
//
//  Created by 姜锋 on 2025/8/16.
//

import SwiftUI

struct BattleListShiftCardView: View {
    let status: BattleGroupStatus
    
    var timeSpanText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        // if status.startTime is not this year, show year
        if Calendar.current.component(.year, from: status.startTime) != Calendar.current.component(.year, from: Date()){
            formatter.dateFormat = "yyyy MM/dd HH:mm"
        }
        return "\(formatter.string(from: status.startTime)) - \(formatter.string(from: status.endTime))"
    }

    var body: some View {
        VStack(spacing: -1) {
            VStack{
                HStack{
                    Text(timeSpanText)
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
            .padding([.leading, .top, .trailing], 13)
            .padding(.bottom, 11)
            .frame(height: 79)
            .background(
                GrayscaleTextureView(
                    texture: .bubble,
                    foregroundColor: Color.battleDetailStreakForeground,
                    backgroundColor: Color.listItemBackground
                )
                .frame(height: 100),
                alignment: .topLeading
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack { }
                .frame(maxWidth: .infinity, minHeight: 19, maxHeight: 19)
                .overlay(
                    GrayscaleTextureView(
                        texture: .bubble,
                        foregroundColor: Color.battleDetailStreakForeground,
                        backgroundColor: Color.listItemBackground
                    )
                    .frame(height: 100)
                    .offset(y: -78)
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
                            .padding(.trailing, 24)
                    ),
                    alignment: .topLeading
                )
                .overlay {
                    HStack(spacing:0){
                        Text("\(status.count)场对战")
                            .font(.splatoonFont(size: 12))
                        if status.disconnectCount != 0{
                            Text("<\(status.disconnectCount)场掉线>")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(Color.waveDefeat)
                        }
                    }
                    .foregroundStyle(Color.green)
                    .offset(y:2)
                }

        }
        .frame(height: 97)
        .padding(.top, 5)
        .rotationEffect(.degrees(-1))
        .clipped(antialiased: true)
        .padding([.leading, .trailing])
        .padding(.top, 15)
        .padding(.bottom, 0.1)
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
