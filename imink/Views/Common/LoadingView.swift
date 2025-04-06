import Foundation
import SwiftUI

struct LoadingView: View {

    let size:CGFloat
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(alignment: .center){
            Spacer()
            Image(.tabBarHome)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.gray)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    rotationAngle = 360
                }
                .animation(
                    Animation.linear(duration: 3)
                        .repeatForever(autoreverses: false),
                    value: rotationAngle
                )
            Text("Loading...")
                .font(.splatoonFont(size: size/4))
            Spacer()
        }
    }
}
