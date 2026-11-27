import SwiftUI
import SplatDatabase

struct CoopDetailMemberView:View {
    let result: CoopPlayerResult
    @Binding var activePlayer: CoopPlayerResult?
    @Binding var showPlayerDetail: Bool
    @Binding var hoveredMember: Bool
    
    var body: some View {
        HStack{
            VStack(alignment: .leading, spacing:5){
                Text(result.player!.name)
                    .font(.appBody)
                Text("\("boss_salmonids".localized) x\(result.defeatEnemyCount)")
                    .font(.appCaptionMono)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing,spacing: 0){
                HStack{
                    HStack{
                        if let weapons = result.weapons{
                            ForEach(weapons.indices, id:\.self){i in
                                Image(weapons[i])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                    .background(Color(.sRGB, white: 121 / 255.0, opacity: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    if let specialWeaponName = result.specialWeaponName{
                        SpecialWeaponImage(imageName: specialWeaponName,size: 15)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 24)

                HStack{
                    HStack(spacing:2){
                        Image(.golden)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 12)
                        Text("\(result.goldenDeliverCount)").font(.appCaptionMono)+Text("+\(result.goldenAssistCount)").font(.appSubCaptionMono)
                    }

                    Group{
                        HStack(spacing:2){
                            Image(.egg)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 12)
                            Text("\(result.deliverCount)")
                        }

                        HStack(spacing:2){
                            Image(result.player!.species ? .rescueINKLING : .rescueOCTOLING)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 12)
                            Text("\(result.rescueCount)")
                        }

                        HStack(spacing:2){
                            Image(result.player!.species ? .rescuedINKLING : .rescuedOCTOLING)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 12)
                            Text("\(result.rescuedCount)")
                        }
                    }
                    .font(.appCaptionMono)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        }
        .frame(minHeight: 48)
        .overlay {
            TouchDownAndTouchUpGestureView {
                activePlayer = result
                hoveredMember = true
            } touchMovedCallBack: { distance in
                if distance > 10 {
                    hoveredMember = false
                }
            } touchUpCallBack: {
                if hoveredMember {
                    withAnimation {
                        showPlayerDetail = true
                    }
                    hoveredMember = false
                }
            }
        }
    }
}
