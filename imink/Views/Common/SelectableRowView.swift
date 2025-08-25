import SwiftUI

struct SelectableRowView<Content: View>: View {
    let content: Content
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var rotationAngle: Double = 0
    
    init(
        isSelectionMode: Bool,
        isSelected: Bool,
        onTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self.onTap = onTap
        self.content = content()
    }
    
    var body: some View {
        content
            .overlay(
                // 选中状态的边缘标记
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    .opacity(isSelectionMode ? 1 : 0)
            )
            .rotationEffect(.degrees(isSelectionMode ? rotationAngle : 0))
            .animation(.easeInOut(duration: 0.3), value: isSelectionMode)
            .onTapGesture {
                if isSelectionMode {
                    onTap()
                }
            }
            .onAppear {
                if isSelectionMode {
                    startWiggleAnimation()
                }
            }
            .onChange(of: isSelectionMode) { _, newValue in
                if newValue {
                    startWiggleAnimation()
                } else {
                    stopWiggleAnimation()
                }
            }
    }
    
    private func startWiggleAnimation() {
        // 创建更自然的摆动动画：正时针和逆时针交替
        let wiggleAnimation = Animation
            .easeInOut(duration: 0.1)
            .repeatForever(autoreverses: true)
        
        withAnimation(wiggleAnimation) {
            rotationAngle = 1.0
        }
        
        // 添加一些随机延迟，让不同行的摆动不完全同步，更自然
        let randomDelay = Double.random(in: 0.0...0.05)
        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
            withAnimation(wiggleAnimation) {
                rotationAngle = -1.0
            }
        }
    }
    
    private func stopWiggleAnimation() {
        withAnimation(.easeInOut(duration: 0.2)) {
            rotationAngle = 0
        }
    }
}
