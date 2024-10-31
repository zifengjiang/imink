//
//  GearView.swift
//  imink
//
//  Created by 姜锋 on 10/28/24.
//

import SwiftUI
import SplatDatabase

struct GearView: View {

    let gear:String
    let primaryPower:String
    let additionalPowers:[String]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            VStack(spacing:0){
                Image(gear)
                    .resizable()
                    .scaledToFit()
                    .frame(width:size.height*0.7,height: size.width*0.7)
                HStack(alignment: .bottom, spacing: size.width/30){
                    Image(primaryPower)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width*0.3,height: size.width*0.3)
                        .background{
                            Capsule()
                                .foregroundStyle(.black.opacity(0.8))
                        }
                    ForEach(additionalPowers.indices,id: \.self){ index in
                        Image(additionalPowers[index] == "None" ? "UnknownGear" : additionalPowers[index])
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width*0.2,height: size.width*0.2)
                            .background{
                                Capsule()
                                    .foregroundStyle(.black.opacity(0.8))
                            }
                    }
                }
            }
        }
    }
}

extension GearView {
    init(gear:Gear){
        self.gear = gear.gear
        self.primaryPower = gear.primaryPower
        self.additionalPowers = gear.additionalPowers
    }
}



#Preview {
    GearView(gear: "Clt_AMB008", primaryPower: "SubInk_Save", additionalPowers: ["SubInk_Save","SubInk_Save","SubInk_Save"])
        .frame(width: 100,height: 100)
}
