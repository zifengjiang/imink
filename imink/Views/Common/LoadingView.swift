import Foundation
import SwiftUI

struct LoadingView: View {
    let size: CGFloat
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Spacer()
            Image(.tabBarHome)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    rotationAngle = 360
                }
                .animation(
                    Animation.linear(duration: 3)
                        .repeatForever(autoreverses: false),
                    value: rotationAngle
                )
            Text("loading_text")
                .font(.appCaption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
