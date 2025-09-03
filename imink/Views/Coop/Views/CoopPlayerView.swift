import SwiftUI
import SplatDatabase

struct CoopPlayerView: View {
    let result: CoopPlayerResult?
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            if let result = result, let player = result.player {
                NameplateView(result: result)
                    .frame(height: 60)
                
                if let uniformName = player.uniformName {
                    Image(uniformName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                }
                
//                VStack(spacing: 8) {
//                    HStack(spacing: 15) {
//                        VStack(spacing: 4) {
//                            Image(.golden)
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                            Text("\(result.goldenDeliverCount)")
//                                .font(.splatoonFont(size: 16))
//                            Text("金蛋")
//                                .font(.splatoonFont(size: 12))
//                                .foregroundStyle(.secondary)
//                        }
//                        
//                        VStack(spacing: 4) {
//                            Image(.egg)
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                            Text("\(result.deliverCount)")
//                                .font(.splatoonFont(size: 16))
//                            Text("普通蛋")
//                                .font(.splatoonFont(size: 12))
//                                .foregroundStyle(.secondary)
//                        }
//                        
//                        VStack(spacing: 4) {
//                            Image(player.species ? .rescueINKLING : .rescueOCTOLING)
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                            Text("\(result.rescueCount)")
//                                .font(.splatoonFont(size: 16))
//                            Text("救援")
//                                .font(.splatoonFont(size: 12))
//                                .foregroundStyle(.secondary)
//                        }
//                    }
//                    
//                    HStack(spacing: 15) {
//                        VStack(spacing: 4) {
//                            Image(.salmonRun)
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                            Text("\(result.defeatEnemyCount)")
//                                .font(.splatoonFont(size: 16))
//                            Text("击败敌人")
//                                .font(.splatoonFont(size: 12))
//                                .foregroundStyle(.secondary)
//                        }
//                        
//                        if let specialWeaponName = result.specialWeaponName {
//                            VStack(spacing: 4) {
//                                SpecialWeaponImage(imageName: specialWeaponName, size: 20)
//                                Text("特殊武器")
//                                    .font(.splatoonFont(size: 12))
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
//                    }
//                }
            }
        }
//        .frame(width: 250, height: 300)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    CoopPlayerView(result: nil)
}
