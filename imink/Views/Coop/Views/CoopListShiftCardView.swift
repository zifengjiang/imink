import SwiftUI

struct CoopListShiftCardView: View {
    let status: CoopGroupStatus

    var timeSpanText:String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return "\(formatter.string(from: status.startTime)) - \(formatter.string(from: status.endTime))"
    }

    var body: some View {
        VStack(spacing: -1) {
            VStack{
                HStack{
                    Text(timeSpanText)
                        .font(.splatoonFont(size: 12))
                    Spacer()
                    if let stage = status._stage{
                        Text(stage.nameId.localizedFromSplatNet)
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    
                    StatusView(status: status)

                    Spacer()
                    if let suppliedWeapon = status._suppliedWeapon{
                        HStack{
                            ForEach(suppliedWeapon.indices,id: \.self) { i in
                                Image(suppliedWeapon[i].name)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                            }
                            if suppliedWeapon.count < 4{
                                let weapons = Array(repeating: suppliedWeapon.last!, count: 4 - suppliedWeapon.count)
                                ForEach(weapons.indices, id: \.self) { i in
                                    Image(weapons[i].name)
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
                        Text("\(status.count)场打工")
                            .font(.splatoonFont(size: 12))
                        if status.disconnect != 0{
                            Text("<\(status.disconnect)场掉线>")
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

    struct StatusView:View {
        let status:CoopGroupStatus
        var hSpace: CGFloat = 5
        var vSpace: CGFloat = 8
        var body: some View {
            VStack(alignment: .leading,spacing: vSpace){
                HStack(spacing: hSpace){
                    HStack(spacing: 3){
                        Image(.salmonRun)
                            .resizable()
                            .bold()
                            .foregroundStyle(Color.green)
                            .frame(width: 12,height: 12)
                        Text("\(status.avg_defeatEnemyCount, places: 1)")
                            .font(.splatoonFont(size: 12))
                    }
                    .frame(width: 45, alignment: .leading)

                    HStack(spacing: 3){
                        Image(.golden)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(status.avg_goldenDeliverCount, places:1)")
                            .font(.splatoonFont(size: 12)) + Text("<\(status.avg_goldenAssistCount, places:1)>")
                            .font(.splatoonFont(size: 9)).foregroundColor(.secondary)
                    }
                }

                HStack(spacing: hSpace){
                    HStack(spacing: 3){
                        Image(.jobShiftCardHelp)
                            .resizable()
                            .bold()
                            .foregroundStyle(Color.green)
                            .frame(width: 12,height: 12)
                        Text("\(status.avg_rescueCount, places: 1)")
                            .font(.splatoonFont(size: 12))
                    }
                    .frame(width: 45, alignment: .leading)

                    HStack(spacing: 3){
                        Image(.jobShiftCardDead)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(status.avg_rescuedCount, places:1)")
                            .font(.splatoonFont(size: 12))
                    }
                }
            }
        }
    }
}

//#Preview {
//    CoopListShiftCardView(card: CoopShiftCard(id: 1, startTime: Date(), endTime: Date.init(timeInterval: 30000, since: Date()), enemy: 21.2, egg: 39.5, eggAssist: 6.4, rescue: 1.3, rescued: 0.9, stage: "Q29vcFN0YWdlLTk=",  count: 31))
//        .preferredColorScheme(.dark)
//}
