import SwiftUI
import SplatDatabase
import Charts

struct SalmonRunStatusView:View {
    let status:CoopGroupStatus
    let coopSummary:CoopSummary?

    var body: some View {

        GeometryReader{ geometry in
            CarouselView(activeIndex: .constant(1), autoScrollDuration: 150) {
                HStack(spacing:8){
                    VStack{
                        HStack{
                            Chart {
                                SectorMark(angle: .value("1", status.disconnect))
                                    .foregroundStyle(Color.gray)
                                SectorMark(angle: .value("2", status.failure))
                                    .foregroundStyle(Color.waveDefeat)
                                SectorMark(angle: .value("3", status.clear))
                                    .foregroundStyle(Color.waveClear)
                            }
                            .opacity(0.8)
                            .frame(width: 25, height: 25)

                            Text("通关率")
                                .font(.splatoonFont(size: 16))

                            Text("\(status.clearRate*100, places: 3)%")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.secondary)
                        }

                        HStack{
                            Spacer()

                            VStack{
                                Text("Clear")
                                    .font(.splatoonFont(size: 10))
                                    .foregroundStyle(.secondary)
                                Text("\(status.clear)")
                                    .font(.splatoonFont(size: 24))
                                    .foregroundStyle(.waveClear)
                            }

                            Spacer()

                            VStack{
                                Text("Failure")
                                    .font(.splatoonFont(size: 10))
                                    .foregroundStyle(.secondary)
                                Text("\(status.failure)")
                                    .font(.splatoonFont(size: 24))
                                    .foregroundStyle(.waveDefeat)
                            }

                            Spacer()

                            if status.disconnect != 0 {
                                VStack{
                                    Text("Disconnect")
                                        .font(.splatoonFont(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text("\(status.disconnect)")
                                        .font(.splatoonFont(size: 24))
                                        .foregroundStyle(.waveDefeat)
                                }

                                Spacer()
                            }
                        }

                    }
                    .frame(width: geometry.size.width/2 - 4)
                    .padding([.top,.bottom],5)
                    .frame(height: geometry.size.height)
                    .background(Color.listItemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))


                    VStack(alignment: .leading){
                        HStack{
                            CoopListShiftCardView.StatusView(status: status, hSpace: 0, vSpace: 3)
                            if let weapons = status._suppliedWeapon {
                                LazyHGrid(rows: [GridItem(.adaptive(minimum: 20)),GridItem(.adaptive(minimum: 20))], spacing: 2){
                                    ForEach(weapons.indices, id: \.self){ index in
                                        Image(weapons[index].name)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20,height: 20)
                                    }
                                }
                            }
                        }

                        if let point = coopSummary?.pointCard.regularPoint{
                            Text("现有点数 \(point)p")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(.waveClear)
                        }
                    }
                    .frame(width: geometry.size.width/2 - 4)
                    .padding([.top,.bottom],5)
                    .frame(height: geometry.size.height)
                    .background(Color.listItemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))



                }
                .frame(maxWidth: .infinity)

                HStack(spacing:8){
                    VStack(spacing:1){
                        Text("鳞片")
                            .font(.splatoonFont(size: 16))
                            .foregroundStyle(Color(.spGreen))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.leading, 8)
                        HStack{
                            VStack(spacing: 1){
                                Image(.scale1)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                Text("x\(coopSummary?.scale.bronze ?? 0)")
                                    .font(.splatoonFont(size: 16))
                            }
                            VStack(spacing: 1){
                                Image(.scale2)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                Text("x\(coopSummary?.scale.silver ?? 0)")
                                    .font(.splatoonFont(size: 16))
                            }

                            VStack(spacing: 1){
                                Image(.scale3)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                Text("x\(coopSummary?.scale.gold ?? 0)")
                                    .font(.splatoonFont(size: 16))
                            }
                        }
                    }
                    .frame(width: geometry.size.width/2 - 4)
                    .padding([.top,.bottom],5)
                    .frame(height: geometry.size.height)
                    .background(Color.listItemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading,spacing: 2){
                        if let gradeName = coopSummary?.regularGrade, let gradePoint = coopSummary?.regularGradePoint{
                            Text("\(gradeName.localizedFromSplatNet) \(gradePoint)")
                                .font(.splatoonFont(size: 16))
                                .foregroundStyle(Color.waveClear)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 6)
                            ProgressBar(fillPercentage: gradePoint >= 100 ? 1 : Double(gradePoint)/Double(100))
                                .padding(.horizontal,8)
                                .padding(.vertical, 2)
                        }

                        Text("平均通关的WAVE数")
                            .font(.splatoonFont(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                        Text("\(coopSummary?.regularAverageClearWave ?? 0, places: 1)")
                            .font(.splatoonFont(size: 20))
                            .foregroundStyle(.waveClear)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 8)
                    }
                    .frame(width: geometry.size.width/2 - 4)
                    .padding([.top,.bottom],5)
                    .frame(height: geometry.size.height)
                    .background(Color.listItemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    
                }
                .frame(maxWidth: .infinity)

                if let pointCard = coopSummary?.pointCard{
                    HStack(spacing:8){
                        VStack{
                            HStack {
                                Spacer()
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("打工次数")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                    Text("已收集的金鲑鱼卵")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                    Text("已收集的鲑鱼卵")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 10) {
                                    Text("\(pointCard.playCount)")
                                        .font(.splatoonFont(size: 12))
                                    Text("\(pointCard.goldenDeliverCount)")
                                        .font(.splatoonFont(size: 12))
                                    Text("\(pointCard.deliverCount)")
                                        .font(.splatoonFont(size: 12))
                                }
                                Spacer()
                            }

                        }
                        .frame(width: geometry.size.width/2 - 4)
                        .padding([.top,.bottom],5)
                        .frame(height: geometry.size.height)
                        .background(Color.listItemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack{
                            HStack {
                                Spacer()
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("击退头目鲑鱼的次数")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                    Text("救援次数")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                    Text("累计点数")
                                        .font(.splatoonFont(size: 12))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 10) {
                                    Text("\(pointCard.defeatBossCount)")
                                        .font(.splatoonFont(size: 12))
                                    Text("\(pointCard.rescueCount)")
                                        .font(.splatoonFont(size: 12))
                                    Text("\(pointCard.totalPoint)")
                                        .font(.splatoonFont(size: 12))
                                }
                                Spacer()
                            }

                        }
                        .frame(width: geometry.size.width/2 - 4)
                        .padding([.top,.bottom],5)
                        .frame(height: geometry.size.height)
                        .background(Color.listItemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

        }
    }

}

//#Preview(body: {
//    SalmonRunStatusView(status: .init(clear: 30, failure: 2, abort: 2, kill: 21.2, egg: 43.2, rescue: 1.3, rescued: 0.3))
//})
