//
//  RotationView.swift
//  imink
//
//  Created by 姜锋 on 11/1/24.
//

import SwiftUI


struct RotatingImageView: View {
    @State private var rotationAngle: Double = 0
    let size:CGFloat

    var body: some View {
        Image("TabBarHome")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.accent)
            .frame(width: 20, height: 20)
            .rotationEffect(.degrees(rotationAngle))
            .onAppear {
                rotationAngle = 360
            }
            .animation(
                Animation.linear(duration: 1)
                    .repeatForever(autoreverses: false),
                value: rotationAngle
            )
    }

}


#Preview {
    RotatingImageView(size: 20)
}
