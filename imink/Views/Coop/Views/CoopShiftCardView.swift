import SwiftUI

struct CoopShiftCardView: View {
    let card: CoopShiftCard

    var timeSpanText:String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return "\(formatter.string(from: card.startTime)) - \(formatter.string(from: card.endTime))"
    }

    var body: some View {
        VStack(spacing: -1) {
            HStack {
                VStack(alignment: .leading,spacing: 0){
                    Text(timeSpanText)
                        .font(.splatoonFont2(size: 12))
                    VStack(alignment: .leading,spacing: 3){
                        HStack(spacing: 2){
                            HStack(spacing: 3){
                                Image(.salmonRun)
                                    .resizable()
                                    .bold()
                                    .foregroundStyle(Color.green)
                                    .frame(width: 12,height: 12)
                                Text("\(card.enemy, places: 1)")
                                    .font(.splatoonFont2(size: 12))
                            }
                            .frame(width: 45, alignment: .leading)

                            HStack(spacing: 3){
                                Image(.golden)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                Text("\(card.egg, places:1)")
                                    .font(.splatoonFont2(size: 12)) + Text("<\(card.eggAssist, places:1)>")
                                    .font(.splatoonFont2(size: 9)).foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 2){
                            HStack(spacing: 3){
                                Image(.jobShiftCardHelp)
                                    .resizable()
                                    .bold()
                                    .foregroundStyle(Color.green)
                                    .frame(width: 12,height: 12)
                                Text("\(card.rescue, places: 1)")
                                    .font(.splatoonFont2(size: 12))
                            }
                            .frame(width: 45, alignment: .leading)

                            HStack(spacing: 3){
                                Image(.jobShiftCardDead)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                Text("\(card.rescued, places:1)")
                                    .font(.splatoonFont2(size: 12))
                            }
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing,spacing: 10){
                    Text(card.stage.localizedFromSplatNet)
                        .font(.splatoonFont(size: 10))
                        .foregroundStyle(.secondary)

                    HStack{
                        ForEach(card.weapons.indices,id: \.self) { i in
                            Image(card.weapons[i])
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }
                        if card.weapons.count < 4{
                            let weapons = Array(repeating: card.weapons.last!, count: 4 - card.weapons.count)
                            ForEach(weapons.indices, id: \.self) { i in
                                Image(weapons[i])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                    .padding([.leading, .trailing], 10)
                    .padding([.top, .bottom], 6)
                    .background(Color(.sRGB, white: 151 / 255.0, opacity: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .padding(.bottom, 2)
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
                        Text("\(card.count)场打工")
                            .font(.splatoonFont(size: 12))
//                        if stats.count != details.count{
//                            Text("<\(details.count-stats.count)场掉线>")
//                                .inkFont(.font1, size: 10, relativeTo: .body)
//                                .foregroundStyle(Color.waveDefeat)
//                        }
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
}

#Preview {
    CoopShiftCardView(card: CoopShiftCard(id: 1, startTime: Date(), endTime: Date.init(timeInterval: 30000, since: Date()), enemy: 21.2, egg: 39.5, eggAssist: 6.4, rescue: 1.3, rescued: 0.9, stage: "Q29vcFN0YWdlLTk=",  count: 31))
        .preferredColorScheme(.dark)
}
