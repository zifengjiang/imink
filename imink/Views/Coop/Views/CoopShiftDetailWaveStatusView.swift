import SwiftUI

struct CoopShiftDetailWaveStatusView: View {
    let result:CoopWaveStatus
    let waterLevel = ["low_tide","normal","high_tide"]
    var waveHeight: CGFloat {
        switch result.waterLevel {
        case 2:
            return 72
        case 1:
            return 49
        case 0:
            return 16
        default:
            return 49
        }
    }
    var body: some View {
        VStack {
            ZStack {
                VStack {
                    Spacer()
                    WaveShape()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.waveGradientStart, Color.listItemBackground]),
                            startPoint: .top,
                            endPoint: .bottom))
                        .frame(height: waveHeight)
                }

                VStack {
                    VStack(spacing:4){
                        Text("\(result.successCount)").foregroundStyle(.waveClear) +
                        Text(" / ") +
                        Text("\(result.failCount)").foregroundStyle(.waveDefeat)

                        if let teamDeliverCount = result.teamDeliverCount, let deliverNorm = result.deliverNorm{
                            Text("\(teamDeliverCount, places: 1)/\(deliverNorm, places: 1)")
                        }else{
                            Text("-")
                        }

                        Text("\(waterLevel[result.waterLevel])".localized)

                        
                        if let eventWaveGroup = result.eventWaveGroup{
                            Text("\(eventWaveGroup.localizedFromSplatNet)")
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                        }else{
                            Text("-")
                        }

                        HStack(spacing:0){
                            Image(.golden)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
                            Text("x\(result.goldenPopCount)").font(.splatoonFont(size: 10))
                        }
                        Text("appearances_number").font(.splatoonFont(size: 8))
                            .foregroundStyle(.secondary)

                    }
                    .font(.splatoonFont(size: 15))
                    .padding(.top,10)
                    Spacer()
                }
            }
            .frame(width: 85, height: 110)
            .background(Color.listItemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//            .overlay {
//                Image(pass ? .jobWaveClear : .jobWaveDefeat)
//                    .position(x:80,y:3)
//            }
//            if let usedSpecialWeapons = result.usedSpecialWeapons{
//                let columns = Array(repeating: GridItem(.fixed(13)), count: min(usedSpecialWeapons.count, 4))
//                LazyVGrid(columns: columns, spacing: 2) {
//                    ForEach(0..<usedSpecialWeapons.count, id: \.self){index in
//                        Rectangle()
//                            .overlay {
//                                SpecialWeaponImage(imageName: usedSpecialWeapons[index])
//                            }
//                            .foregroundStyle(Color.salmonRunSpecialBackground)
//                            .frame(width: 13, height: 13)
//                            .clipShape(Capsule())
//                    }
//                }
//                .frame(width: 85)
//            }
        }
    }
}

//#Preview {
//    CoopShiftDetailWaveStatusView()
//}
