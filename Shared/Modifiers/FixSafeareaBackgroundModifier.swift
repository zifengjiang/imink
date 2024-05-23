import SwiftUI

extension View {
    func fixSafeareaBackground() -> some View {
        self.modifier(FixSafeareaBackgroundModifier())
    }
}

struct FixSafeareaBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
                // FIXME: Fix navigationBar and tabBar background is white.
            Rectangle()
                .fill(Color("ListBackgroundColor"))
                .edgesIgnoringSafeArea(.all)

            content
        }
    }
}
