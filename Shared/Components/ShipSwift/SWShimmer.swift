import SwiftUI

struct SWShimmer<Content: View>: View {
    private let content: Content
    private let duration: Double
    private let delay: Double

    @State private var isAnimating = false

    init(
        duration: Double = 1.6,
        delay: Double = 0.8,
        @ViewBuilder content: () -> Content
    ) {
        self.duration = duration
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.28),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 0.45)
                    .offset(x: isAnimating ? geometry.size.width * 1.15 : -geometry.size.width * 0.6)
                    .animation(
                        .linear(duration: duration)
                            .repeatForever(autoreverses: false)
                            .delay(delay),
                        value: isAnimating
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .task {
                isAnimating = true
            }
    }
}

extension View {
    func swShimmer(duration: Double = 1.6, delay: Double = 0.8) -> some View {
        SWShimmer(duration: duration, delay: delay) {
            self
        }
    }
}
