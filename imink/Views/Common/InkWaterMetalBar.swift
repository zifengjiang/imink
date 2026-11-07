import SwiftUI

/// 用片元着色器绘制的墨水液面（实验中，暂未启用）。
///
/// 状态：着色器与 SwiftUI 接线均已跑通，但真机上条的高度与波形幅度仍不对
/// （`colorEffect` 的 position 单位与视图实际布局尺寸对不上，导致纵向被压缩），
/// 因此 BattleWaveOverlay 暂时仍使用 Canvas 版 `InkWaterBar`。
/// 继续推进需要：确认 position/size 的单位来源，或改用 MTKView 自行控制投影。
///
/// 与 `InkWaterBar`（Canvas 版）共用同一套实测参数，但把液面、高光带、颜色交界
/// 全部放到 GPU 上逐像素计算，因此能做出矢量绘制做不到的效果：
/// 两色交界处的柔和渗透、边缘毛刺、随液面起伏的高光。
struct InkWaterMetalBar: View {
    struct Segment: Identifiable {
        let id = UUID()
        let color: Color
        let ratio: Double
    }

    let segments: [Segment]

    /// 固定时间戳（预览/截图用），传入后不走进场动画。
    var fixedTime: TimeInterval? = nil

    @State private var riseStart: Date? = nil
    @State private var size: CGSize = .zero
    @State private var didAppear = false

    private static let riseDuration: Double = 0.9

    var body: some View {
        let layout = Layout(segments: segments, width: size.width)

        TimelineView(.animation) { timeline in
            let now = timeline.date
            let time = fixedTime ?? now.timeIntervalSinceReferenceDate
            let elapsed = riseStart.map { now.timeIntervalSince($0) } ?? Self.riseDuration
            let rise = fixedTime == nil
                ? Self.riseEasing(min(max(elapsed / Self.riseDuration, 0), 1))
                : 1

            Rectangle()
                .fill(.white)
                .colorEffect(
                    ShaderLibrary.inkWater(
                        .float(Float(time)),
                        .float(Float(rise)),
                        .float2(Float(size.width), Float(size.height)),
                        .color(layout.colors[0]),
                        .color(layout.colors[1]),
                        .color(layout.colors[2]),
                        .float2(Float(layout.boundaries.0), Float(layout.boundaries.1))
                    )
                )
                // 用真实渲染尺寸驱动着色器，避免 GeometryReader 吞掉父级提案
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { newValue in
                    if newValue != size { size = newValue }
                }
        }
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            riseStart = Date()
        }
    }

    /// 把分段比例换算成「三色 + 两个分界 x 坐标」。
    private struct Layout {
        var colors: [Color] = [.clear, .clear, .clear]
        /// 前两个分界的绝对 x；不存在时给 0（着色器据此跳过）
        var boundaries: (Double, Double) = (0, 0)

        init(segments: [InkWaterMetalBar.Segment], width: CGFloat) {
            let total = max(segments.reduce(0) { $0 + $1.ratio }, 0.0001)
            var cursor: Double = 0
            for (index, segment) in segments.prefix(3).enumerated() {
                colors[index] = segment.color
                cursor += width * segment.ratio / total
                if index == 0 { boundaries.0 = cursor }
                if index == 1 { boundaries.1 = cursor }
            }
            // 单一颜色时没有分界
            if segments.count < 2 { boundaries.0 = 0 }
            if segments.count < 3 { boundaries.1 = 0 }
        }
    }

    private static func riseEasing(_ p: Double) -> Double {
        let c1 = 1.30
        let c3 = c1 + 1
        let value = 1 + c3 * pow(p - 1, 3) + c1 * pow(p - 1, 2)
        return min(max(value, 0), 1.06)
    }
}

#Preview {
    VStack(spacing: 20) {
        InkWaterMetalBar(segments: [
            .init(color: .purple, ratio: 0.382),
            .init(color: Color(red: 0.73, green: 0.91, blue: 0.16), ratio: 0.541)
        ])
        .frame(height: 30)
        .background(.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

        InkWaterMetalBar(segments: [
            .init(color: .yellow, ratio: 0.34),
            .init(color: .blue, ratio: 0.33),
            .init(color: .red, ratio: 0.33)
        ])
        .frame(height: 60)
        .background(.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
    .padding()
    .background(.gray)
}
