import SwiftUI

/// 对战 / 打工列表中「班次卡片」的统一外观。
///
/// 负责气泡纹理底板、折角尾巴、"N 场对战 / 打工" 统计行以及整体倾斜角度，
/// 对战与打工卡片只需要提供中间的统计内容。
struct ShiftCardChrome<Content: View>: View {
    let count: Int
    let unit: String
    let disconnectCount: Int

    private let content: Content

    init(
        count: Int,
        unit: String,
        disconnectCount: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.count = count
        self.unit = unit
        self.disconnectCount = disconnectCount
        self.content = content()
    }

    private var texture: some View {
        GrayscaleTextureView(
            texture: .bubble,
            foregroundColor: Color.battleDetailStreakForeground,
            backgroundColor: Color.listItemBackground
        )
    }

    var body: some View {
        VStack(spacing: -1) {
            content
                .padding([.leading, .top, .trailing], 13)
                .padding(.bottom, 11)
                .frame(height: 79)
                .background(texture.frame(height: 100), alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            tail
        }
        .frame(height: 97)
        .padding(.top, 5)
        .rotationEffect(.degrees(-1))
        .clipped(antialiased: true)
        .padding([.leading, .trailing])
        .padding(.top, 15)
        .padding(.bottom, 0.1)
    }

    private var tail: some View {
        VStack { }
            .frame(maxWidth: .infinity, minHeight: 19, maxHeight: 19)
            .overlay(alignment: .topLeading) {
                texture
                    .frame(height: 100)
                    .offset(y: -78)
                    .mask {
                        VStack {
                            HStack {
                                Spacer()
                                Image(.jobShiftCardTail)
                                    .resizable()
                                    .frame(width: 33, height: 19)
                            }
                            Spacer()
                        }
                        .padding(.trailing, 24)
                    }
            }
            .overlay { countLabel.offset(y: 2) }
    }

    private var countLabel: some View {
        HStack(spacing: 0) {
            Text("\(count)\(unit)")
                .font(.splatoonFont(size: 12))
            if disconnectCount != 0 {
                Text("<\(disconnectCount)场掉线>")
                    .font(.splatoonFont(size: 10))
                    .foregroundStyle(Color.waveDefeat)
            }
        }
        .foregroundStyle(Color.green)
    }
}
