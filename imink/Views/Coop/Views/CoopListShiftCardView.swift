import SwiftUI

struct CoopListShiftCardView: View {
    let status: CoopGroupStatus

    var body: some View {
        ShiftCardChrome(
            count: status.count,
            unit: "场打工",
            disconnectCount: status.disconnect
        ) {
            VStack{
                HStack{
                    Text(status.startTime.toShiftTimeSpanString(end: status.endTime))
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
        }
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
