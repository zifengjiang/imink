import SwiftUI
import SplatDatabase

struct BattlePlayerView: View {
    let player:Player?
    var body: some View {
        VStack(alignment: .center){
            if let player = player{
                NameplateView(player: player)
                if let weapon = player._weapon{
                    HStack{
                        Image(weapon.mainWeapon.name)
                            .resizable()
                            .frame(width: 50, height: 50)
                        VStack{
                            SpecialWeaponImage(imageName: weapon.subWeapon.name,size: 20)
                            SpecialWeaponImage(imageName: weapon.specialWeapon.name,size: 20)
                            
                        }
                    }
                }
                HStack{
                    if let headGear = player._headGear{
                        GearView(gear: headGear)
                    }

                    if let clothes = player._clothingGear{
                        GearView(gear: clothes)
                    }

                    if let shoes = player._shoesGear{
                        GearView(gear: shoes)
                    }
                }
            }

        }
        .frame(width: 200, height: 180)
        .padding()
        .background(.gray)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}



