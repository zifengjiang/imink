import SwiftUI

struct ProgressBar: View {
    var fillPercentage: CGFloat  // 0.0 到 1.0 之间

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle() // 背景条
                    .foregroundColor(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                Rectangle() // 填充条
                    .frame(width: geometry.size.width * fillPercentage)
                    .foregroundColor(Color.waveDefeat)
                    .cornerRadius(10)
            }
        }
        .frame(height: 8) // 指定高度
    }
}
