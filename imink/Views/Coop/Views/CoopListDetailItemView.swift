import SwiftUI

struct CoopListDetailItemView: View {
    
    var coop: CoopListItemInfo

    var dangerRateText:String{
        let dangerRate = coop.dangerRate
        if dangerRate >= 3.33{
            return "MAX!!"
        }
        return "\(Int(dangerRate*100))%"
    }

    var clear:Bool {
        coop.resultWave == coop.rule.waveCount
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if let gradeName = coop.gradeName, let gradePoint = coop.gradePoint {
                    Text(gradeName.localizedFromSplatNet)
                        .font(.splatoonFont(size: 12))
                    Text("\(gradePoint)")
                        .font(.splatoonFont1(size: 12))
                    Rectangle()
                        .foregroundColor(.clear)
                        .overlay(
                            coop.gradeDiff?.image,
                            alignment: .leading
                        )
                        .frame(width: 13, height:13)
                        .padding([.top, .bottom], 0.5)
                }
                Spacer()

                HStack {
                    Text(coop.stage.localizedFromSplatNet)
                        .font(.splatoonFont(size: 12))
                    if let boss = coop.boss,let defeated = coop.haveBossDefeated {
                        Text("/\(boss.localizedFromSplatNet)")
                            .font(.splatoonFont(size: 12))
                            .foregroundStyle(defeated ? Color.green : Color.orange)
                    }
                }
            }
            .padding(.bottom,3)

            HStack {
                Text(clear ? "Clear!!" : "Failure")
                    .font(.splatoonFont1(size: 14))

                Spacer()

                HStack {
                    HStack(spacing: 3){
                        Image(.salmonRun)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(coop.enemyDefeatCount)")
                            .font(.splatoonFont(size: 10))

                    }

                    HStack(spacing: 3){
                        coop._specie.coopRescue
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("\(coop.rescue)")
                            .font(.splatoonFont(size: 10))

                    }

                    HStack(spacing: 3){
                        coop._specie.coopRescued
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("\(coop.rescued)")
                            .font(.splatoonFont(size: 10))

                    }

                    HStack(spacing: 3) {
                        Image(.golden)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(coop.goldenEgg)")
                            .font(.splatoonFont(size: 10))
                    }

                    HStack(spacing: 3) {
                        Image(.egg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(coop.powerEgg)")
                            .font(.splatoonFont(size: 10))
                    }

                }
                .layoutPriority(1)
            }
            .padding(.bottom, 3)

            HStack{
                ForEach(Array(1...coop.rule.waveCount), id: \.self){index in
                    Rectangle()
                        .foregroundColor(coop.resultWave >= index ? clear ? Color.green : Color.orange : Color(.systemGray3))
                        .frame(height: 5)
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text("危险度").font(.splatoonFont(size: 10))+Text(dangerRateText)
                    .font(.splatoonFont(size: 10))
                Spacer()
                Text("\(coop.time.toPlayedTimeString())")
                    .font(.splatoonFont(size: 10))
            }
            .foregroundColor(Color(.systemGray2))
            .padding(.top, 1)
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

#Preview {
    CoopListDetailItemView(coop: CoopListItemInfo(id: 1, rule: .regular , grade: 8, gradePoint: 999, gradeDiff: .up, dangerRate: 3.33,enemyDefeatCount:21, specie:true, stage: "Q29vcFN0YWdlLTk=", boss: "Q29vcEVuZW15LTIz", haveBossDefeated: true, resultWave: 3, goldenEgg: 212, powerEgg: 5341, rescue: 1, rescued: 0, time: Date.init(timeInterval: -30000000, since: Date()),GroupId: 0))
        .padding(.top, 8)
        .padding([.leading, .trailing])
        .frame(width: 370)
        .previewLayout(.sizeThatFits)
}
