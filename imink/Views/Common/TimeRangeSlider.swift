import SwiftUI
import Combine

public struct TimeRangeSlider: View {
    let lineHeight: Double
    let lineWidth: Double
    let lineCornerRadius: Double
    let circleWidth: Double
    let circleShadowRadius: Double
    let circleBorder: Double
    let leftCircleBorderColor: Color
    let rightCircleBorderColor: Color
    let leftCircleColor: Color
    let rightCircleColor: Color
    let lineColorInRange: AnyShapeStyle
    let lineColorOutOfRange: Color
    let shadow: Color
    
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    @State var minDate: Date
    @State var maxDate: Date
    @State var hasAppeared = false
    @State var leftSliderPosition: Double
    @State var rightSliderPosition: Double
    
    public init(lineHeight: Double = 4,
                lineWidth: Double = 300,
                lineCornerRadius: Double = 2,
                circleWidth: Double = 24,
                circleShadowRadius: Double = 16,
                circleBorder: Double = 2,
                minDate: Date,
                maxDate: Date,
                leftCircleBorderColor: Color = .accentColor,
                rightCircleBorderColor: Color = .accentColor,
                leftCircleColor: Color = .white,
                rightCircleColor: Color = .white,
                lineColorInRange: AnyShapeStyle = AnyShapeStyle(.red),
                lineColorOutOfRange: Color = .gray.opacity(0.3),
                shadow: Color = .black.opacity(0.1),
                startDate: Binding<Date>,
                endDate: Binding<Date>) {
        self.lineHeight = lineHeight
        self.lineWidth = lineWidth
        self.lineCornerRadius = lineCornerRadius
        self.circleWidth = circleWidth
        self.circleShadowRadius = circleShadowRadius
        self.circleBorder = circleBorder
        self.minDate = minDate
        self.maxDate = maxDate
        self._startDate = startDate
        self._endDate = endDate
        self.leftCircleBorderColor = leftCircleBorderColor
        self.rightCircleBorderColor = rightCircleBorderColor
        self.leftCircleColor = leftCircleColor
        self.rightCircleColor = rightCircleColor
        self.lineColorInRange = lineColorInRange
        self.lineColorOutOfRange = lineColorOutOfRange
        self.shadow = shadow
        
        // 计算初始滑块位置
        let totalTimeInterval = maxDate.timeIntervalSince(minDate)
        let startTimeInterval = startDate.wrappedValue.timeIntervalSince(minDate)
        let endTimeInterval = endDate.wrappedValue.timeIntervalSince(minDate)
        
        self.leftSliderPosition = (startTimeInterval / totalTimeInterval) * lineWidth
        self.rightSliderPosition = (endTimeInterval / totalTimeInterval) * lineWidth
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景轨道
                RoundedRectangle(cornerSize: CGSize(width: lineCornerRadius, height: lineCornerRadius))
                    .frame(width: lineWidth, height: lineHeight, alignment: .center)
                    .foregroundColor(lineColorOutOfRange)
                
                // 选中范围轨道
                RoundedRectangle(cornerSize: CGSize(width: lineCornerRadius, height: lineCornerRadius))
                    .fill(AnyShapeStyle(lineColorInRange))
                    .frame(
                        width: rightSliderPosition - leftSliderPosition,
                        height: lineHeight,
                        alignment: .center)
                    .position(
                        x: (rightSliderPosition - leftSliderPosition) / 2 + leftSliderPosition,
                        y: geo.frame(in: .local).midY)
                
                // 左滑块
                ZStack {
                    Circle()
                        .fill(leftCircleBorderColor)
                        .frame(width: circleWidth, height: circleWidth, alignment: .center)
                        .shadow(color: shadow, radius: circleShadowRadius, x: 0, y: 4)
                    Circle()
                        .fill(leftCircleColor)
                        .frame(width: circleWidth - circleBorder, height: circleWidth - circleBorder, alignment: .center)
                }
                .position(x: leftSliderPosition, y: geo.frame(in: .local).midY)
                .gesture(dragLeftSlider)
                .hoverEffect()
                
                // 右滑块
                ZStack {
                    Circle()
                        .fill(rightCircleBorderColor)
                        .frame(width: circleWidth, height: circleWidth, alignment: .center)
                        .shadow(color: shadow, radius: circleShadowRadius, x: 0, y: 4)
                    Circle()
                        .fill(rightCircleColor)
                        .frame(width: circleWidth - circleBorder, height: circleWidth - circleBorder, alignment: .center)
                }
                .position(x: rightSliderPosition, y: geo.frame(in: .local).midY)
                .gesture(dragRightSlider)
                .hoverEffect()
            }
        }
        .frame(width: lineWidth, height: circleWidth, alignment: .center)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                updateSliderPositions()
            }
        }
        .onChange(of: startDate) { _, _ in
            updateSliderPositions()
        }
        .onChange(of: endDate) { _, _ in
            updateSliderPositions()
        }
    }
    
    private func updateSliderPositions() {
        let totalTimeInterval = maxDate.timeIntervalSince(minDate)
        let startTimeInterval = startDate.timeIntervalSince(minDate)
        let endTimeInterval = endDate.timeIntervalSince(minDate)
        
        leftSliderPosition = (startTimeInterval / totalTimeInterval) * lineWidth
        rightSliderPosition = (endTimeInterval / totalTimeInterval) * lineWidth
    }
    
    var dragLeftSlider: some Gesture {
        DragGesture()
            .onChanged { value in
                updateLeftSlider(value: value)
            }
    }
    
    func updateLeftSlider(value: DragGesture.Value) {
        // 左边滑块以右边边缘为准，触摸位置需要减去滑块半径
        let touchPosition = value.location.x - circleWidth / 2
        let newPosition = max(0, min(touchPosition, rightSliderPosition - circleWidth / 2))
        leftSliderPosition = newPosition
        
        let ratio = newPosition / lineWidth
        let totalTimeInterval = maxDate.timeIntervalSince(minDate)
        let newTimeInterval = ratio * totalTimeInterval
        let newDate = minDate.addingTimeInterval(newTimeInterval)
        
        if newDate != startDate {
            startDate = newDate
            generateHapticFeedback()
        }
    }
    
    var dragRightSlider: some Gesture {
        DragGesture()
            .onChanged { value in
                updateRightSlider(value: value.location.x)
            }
    }
    
    func updateRightSlider(value: Double) {
        // 右边滑块以左边边缘为准，触摸位置需要加上滑块半径
        let touchPosition = value + circleWidth / 2
        let newPosition = max(leftSliderPosition + circleWidth / 2, min(touchPosition, lineWidth))
        rightSliderPosition = newPosition
        
        let ratio = newPosition / lineWidth
        let totalTimeInterval = maxDate.timeIntervalSince(minDate)
        let newTimeInterval = ratio * totalTimeInterval
        let newDate = minDate.addingTimeInterval(newTimeInterval)
        
        if newDate != endDate {
            endDate = newDate
            generateHapticFeedback()
        }
    }
    
    func generateHapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// 预览
#Preview {
    VStack(spacing: 20) {
        Text("时间范围选择器")
            .font(.title)
        
        TimeRangeSlider(
            minDate: Date().addingTimeInterval(-30 * 24 * 3600), // 30天前
            maxDate: Date(), // 今天
            startDate: .constant(Date().addingTimeInterval(-7 * 24 * 3600)), // 7天前
            endDate: .constant(Date())
        )
        
        Text("拖动滑块选择时间范围")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
