import SwiftUI
import UIKit
import CoreMotion

// MARK: - 颜色工具

extension Color {
    /// 提高亮度、降低饱和度，用来做"水面高光带"。
    func inkHighlight(_ factor: Double = 0.55) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return Color(hue: Double(h),
                     saturation: Double(s) * (1 - factor * 0.75),
                     brightness: min(1, Double(b) + factor * 0.5),
                     opacity: Double(a))
    }

    /// 压低亮度，用来做墨水"沉积"的下半部分。
    func inkShadow(_ factor: Double = 0.08) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return Color(hue: Double(h),
                     saturation: min(1, Double(s) * 1.05),
                     brightness: Double(b) * (1 - factor),
                     opacity: Double(a))
    }
}

// MARK: - 摇晃输入

/// 设备摇晃/倾斜输入。
///
/// 只在真机上有加速度计，模拟器恒为 0；读数以普通属性暴露，
/// 避免以 60Hz 频率驱动 SwiftUI 状态更新。
final class InkMotionProvider {
    static let shared = InkMotionProvider()

    private let manager = CMMotionManager()
    private(set) var shakeEnergy: Double = 0
    private var lastAcceleration: Double = 0
    private let lock = NSLock()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    private init() {}

    func start() {
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let magnitude = abs(motion.userAcceleration.x) + abs(motion.userAcceleration.y)
            let delta = max(0, magnitude - self.lastAcceleration)
            self.lastAcceleration = magnitude

            self.lock.lock()
            // 冲击叠加，并快速衰减
            self.shakeEnergy = min(1.0, self.shakeEnergy * 0.90 + delta * 2.2)
            self.lock.unlock()
        }
    }

    /// 由渲染循环推进衰减，返回当前冲击强度。
    func consume() -> Double {
        lock.lock(); defer { lock.unlock() }
        let value = shakeEnergy
        shakeEnergy *= 0.94
        return value
    }
}

// MARK: - 墨水液面

/// 对战结算里的涂地比例条。
///
/// 形态来自游戏内逐帧测量：
/// - 一整池墨水，液面是一条横跨全宽的连续波（不是每色独立）
/// - 液面下方有一条更亮的"水面高光带"，它的下边缘是另一条相位滞后的波
/// - 液面峰谷约为容器高的 41%，波长约 0.25 宽，主周期 6s、次周期 4s
/// - 底边平直，颜色分界是竖向着色，不随波动移动
struct InkWaterBar: View {
    struct Segment: Identifiable {
        let id = UUID()
        let color: Color
        /// 该色段占整条的比例（0...1）
        let ratio: Double
    }

    let segments: [Segment]

    /// 固定时间戳（秒）。仅供预览/截图/单测使用，传入后不再依赖 TimelineView。
    var fixedTime: TimeInterval? = nil
    /// 是否跳过入场动画（截图用）。
    var skipEntrance: Bool = false

    /// 入场动画起点；为 nil 时视为已经完成（保证任何情况下都不会画成空的）
    @State private var riseStart: Date? = nil
    @State private var didAppear = false
    private let motion = InkMotionProvider.shared

    // 归一化后的波形参数（相对容器高度 / 容器宽度）
    private enum Wave {
        static let baseLevel = 0.80        // 平均液面高度
        static let amplitude1 = 0.12       // 主频振幅
        static let amplitude2 = 0.05       // 次频振幅
        static let wavesAcross = 3.2       // 主波：波长 = 宽 / 3.2
        static let wavesAcross2 = 2.0
        static let period1 = 6.0
        static let period2 = 4.0
        static let highlightMean = 0.16    // 高光带厚度
        static let highlightAmp = 0.075
        static let highlightMin = 0.06
        static let highlightMax = 0.26
        static let minLevel = 0.35         // 液面最低不低于容器 35%
    }

    /// 入场上升时长（秒）
    private static let riseDuration: Double = 0.9

    /// 带回弹的上升曲线：末端略微超过 1 再回落，像液体涌上来。
    private static func riseEasing(_ p: Double) -> Double {
        let c1 = 1.30
        let c3 = c1 + 1
        let value = 1 + c3 * pow(p - 1, 3) + c1 * pow(p - 1, 2)
        return min(max(value, 0), 1.06)
    }

    var body: some View {
        if let fixedTime {
            Canvas { context, size in
                var ctx = context
                draw(in: &ctx, size: size, time: fixedTime, level: 1)
            }
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let now = timeline.date
                    // 入场进度由时间推导，不依赖 SwiftUI 动画机制
                    let rise = riseStart.map { now.timeIntervalSince($0) / Self.riseDuration } ?? 1
                    draw(in: &context, size: size,
                         time: now.timeIntervalSinceReferenceDate,
                         level: Self.riseEasing(min(max(rise, 0), 1)))
                }
            }
            .onAppear {
                guard !didAppear else { return }
                didAppear = true
                motion.start()
                riseStart = skipEntrance ? nil : Date()
            }
        }
    }

    // MARK: - 绘制

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval, level: Double) {
        let width = size.width
        let height = size.height
        guard width > 1, height > 1 else { return }

        let shake = motion.consume()
        // 每 2pt 采样一次，保证波形平滑；点数过少会把波拉成直线
        let step = 2.0

        // 液面高度（归一化，0 = 容器底，1 = 容器顶）
        func levelAt(_ u: Double) -> Double {
            var v = Wave.baseLevel
            v += Wave.amplitude1 * sin(2 * .pi * Wave.wavesAcross * u + 2 * .pi / Wave.period1 * time)
            v += Wave.amplitude2 * sin(2 * .pi * Wave.wavesAcross2 * u - 2 * .pi / Wave.period2 * time + 1.7)
            // 摇晃冲击：叠加一个更快的行波
            if shake > 0.001 {
                v += shake * 0.18 * sin(2 * .pi * 6.0 * u + 14 * time)
            }
            return min(max(v, Wave.minLevel), 1.0)
        }

        // 高光带厚度（归一化）
        func highlightThickness(_ u: Double) -> Double {
            let raw = Wave.highlightMean
                + Wave.highlightAmp * sin(2 * .pi * 3.2 * u - 2 * .pi / (Wave.period2 * 1.2) * time + 2.4)
                + shake * 0.04 * sin(2 * .pi * 5.0 * u + 11 * time)
            return min(max(raw, Wave.highlightMin), Wave.highlightMax)
        }

        /// 液面在画布上的 y（SwiftUI 的 y 向下）
        func surfaceY(_ u: Double) -> Double {
            height - height * levelAt(u) * level
        }

        // 逐色段绘制；分界点固定，只有液面在动
        var xCursor = 0.0
        let totalRatio = max(segments.reduce(0) { $0 + $1.ratio }, 0.0001)

        for segment in segments {
            let segmentWidth = width * segment.ratio / totalRatio
            let x0 = xCursor
            let x1 = min(width, xCursor + segmentWidth)
            xCursor += segmentWidth
            guard x1 > x0 else { continue }

            drawSegment(
                context: &context,
                x0: x0, x1: x1,
                totalWidth: width,
                height: height,
                step: step,
                time: time,
                isFirst: x0 <= 0.001,
                isLast: x1 >= width - 0.001,
                surfaceY: surfaceY,
                highlightThickness: highlightThickness,
                color: segment.color
            )
        }
    }

    private func drawSegment(
        context: inout GraphicsContext,
        x0: Double,
        x1: Double,
        totalWidth: Double,
        height: Double,
        step: Double,
        time: TimeInterval,
        isFirst: Bool,
        isLast: Bool,
        surfaceY: (Double) -> Double,
        highlightThickness: (Double) -> Double,
        color: Color
    ) {
        let width = x1 - x0
        let columns = max(2, Int(width / step) + 1)

        // 两色交界沿一条缓慢摆动的曲线；相邻两段共用同一条，保证严丝合缝
        func edgeWave(_ y: Double) -> Double {
            let v = y / max(height, 1)
            return 2.0 * sin(v * 3.4 + time * 1.1) + 1.2 * sin(v * 7.1 - time * 0.7)
        }
        func leftEdge(_ y: Double) -> Double { isFirst ? x0 : x0 + edgeWave(y) }
        func rightEdge(_ y: Double) -> Double { isLast ? x1 : x1 + edgeWave(y) }

        func surfaceX(_ i: Int) -> Double { x0 + width * Double(i) / Double(columns - 1) }
        func surfacePoint(_ i: Int) -> CGPoint {
            let px = surfaceX(i)
            return CGPoint(x: px, y: surfaceY(px / totalWidth))
        }

        // ── 主体：液面 → 右侧下沉 → 底部 → 左侧上升
        var body = Path()
        body.move(to: surfacePoint(0))
        for i in 1..<columns { body.addLine(to: surfacePoint(i)) }

        let yRight = surfacePoint(columns - 1).y
        let downSteps = max(4, Int((height - yRight) / 4) + 1)
        for i in 1...downSteps {
            let y = yRight + (height - yRight) * Double(i) / Double(downSteps)
            body.addLine(to: CGPoint(x: rightEdge(y), y: y))
        }

        let yLeft = surfacePoint(0).y
        let upSteps = max(4, Int((height - yLeft) / 4) + 1)
        for i in stride(from: upSteps, through: 1, by: -1) {
            let y = yLeft + (height - yLeft) * Double(i) / Double(upSteps)
            body.addLine(to: CGPoint(x: leftEdge(y), y: y))
        }
        body.closeSubpath()

        // ── 水面高光带：上边缘是液面，下边缘再走回来
        var highlight = Path()
        highlight.move(to: surfacePoint(0))
        for i in 1..<columns { highlight.addLine(to: surfacePoint(i)) }
        for i in stride(from: columns - 1, through: 0, by: -1) {
            let px = surfaceX(i)
            let u = px / totalWidth
            // highlightThickness 是归一化值，需要乘回容器高度
            highlight.addLine(to: CGPoint(x: px, y: surfaceY(u) + highlightThickness(u) * height))
        }
        highlight.closeSubpath()

        // 主体：上亮下暗，模拟液体厚度
        context.fill(
            body,
            with: .linearGradient(
                Gradient(colors: [color.inkShadow(0.04), color, color.inkShadow(0.14)]),
                startPoint: CGPoint(x: 0, y: height * 0.35),
                endPoint: CGPoint(x: 0, y: height)
            )
        )

        // 水面高光带
        context.fill(
            highlight,
            with: .linearGradient(
                Gradient(colors: [color.inkHighlight(0.40), color.inkHighlight(0.22)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: height)
            )
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        InkWaterBar(segments: [
            .init(color: .purple, ratio: 0.382),
            .init(color: .yellow, ratio: 0.541)
        ])
        .frame(height: 30)
        .background(.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

        InkWaterBar(segments: [
            .init(color: .yellow, ratio: 0.33),
            .init(color: .blue, ratio: 0.33),
            .init(color: .red, ratio: 0.34)
        ])
        .frame(height: 60)
        .background(.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
    .padding()
    .background(.gray)
}
