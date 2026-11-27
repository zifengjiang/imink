import SwiftUI

extension View {
    func fixSafeareaBackground() -> some View {
        self.modifier(FixSafeareaBackgroundModifier())
    }
}

struct FixSafeareaBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Rectangle()
                .fill(Color("ListBackgroundColor"))
                .edgesIgnoringSafeArea(.all)

            content
                .floatingTabBarInset()
        }
    }
}
