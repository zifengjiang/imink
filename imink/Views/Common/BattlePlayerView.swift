import SwiftUI
import SplatDatabase

struct BattlePlayerView: View {
    let player:Player?
    var body: some View {
        VStack{
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
                    VStack{
                        if let headGear = player._headGear{
                            Image(headGear.gear)
                                .resizable()
                                .frame(width: 50, height: 50)
                            HStack{
                                Image(headGear.primaryPower)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                ForEach(headGear.additionalPowers.indices, id: \.self){ index in
                                    Image(headGear.additionalPowers[index])
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                            }

                        }
                    }
                    VStack{
                        if let clothes = player._clothingGear{
                            Image(clothes.gear)
                                .resizable()
                                .frame(width: 50, height: 50)
                            HStack{
                                Image(clothes.primaryPower)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                ForEach(clothes.additionalPowers.indices, id: \.self){ index in
                                    Image(clothes.additionalPowers[index])
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                            }
                        }
                    }
                    VStack{
                        if let shoes = player._shoesGear{
                            Image(shoes.gear)
                                .resizable()
                                .frame(width: 50, height: 50)
                            HStack{
                                Image(shoes.primaryPower)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                ForEach(shoes.additionalPowers.indices, id: \.self){ index in
                                    Image(shoes.additionalPowers[index])
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                            }
                        }
                    }
                }
            }

        }
        .frame(width: 200, height: 350)
        .padding()
        .background(Color.gray)
    }
}



