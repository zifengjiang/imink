import SwiftUI

struct RangeSlider: View {
    @Binding var filter: Filter
    var rangeBounds: ClosedRange<Date>
    var dateFormatter: DateFormatter = DateFormatter()

    @GestureState private var dragState = DragState.inactive
    @State private var lowerBoundOffset: CGFloat = 0
    @State private var upperBoundOffset: CGFloat = 0

    init(filter: Binding<Filter>, rangeBounds: ClosedRange<Date>) {
        self._filter = filter
        self.rangeBounds = rangeBounds
        dateFormatter.dateFormat = "yyyy MM/dd HH:mm"
    }

    enum DragState {
        case inactive
        case draggingLower
        case draggingUpper
    }

    var body: some View {
        GeometryReader { geometry in
            let totalSeconds = rangeBounds.upperBound.timeIntervalSince(rangeBounds.lowerBound)
            let lowerBoundSeconds = filter.start.timeIntervalSince(rangeBounds.lowerBound)
            let upperBoundSeconds = filter.end.timeIntervalSince(rangeBounds.lowerBound)

            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)

                    // Track
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: CGFloat(upperBoundSeconds - lowerBoundSeconds) / CGFloat(totalSeconds) * geometry.size.width, height: 4)
                    .offset(x: lowerBoundOffset + geometry.size.width / CGFloat(totalSeconds) * CGFloat(lowerBoundSeconds))
                    .cornerRadius(2)

                    // Lower Bound Knob
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: lowerBoundOffset)
                    .gesture(
                        DragGesture()
                            .updating($dragState) { value, state, _ in
                                state = .draggingLower
                            }
                            .onChanged { value in
                                lowerBoundOffset = value.location.x
                                let newStartDate = rangeBounds.lowerBound.addingTimeInterval(Double(lowerBoundOffset / geometry.size.width) * totalSeconds)
                                if newStartDate < filter.end && newStartDate >= rangeBounds.lowerBound {
                                    filter.start = newStartDate
                                }
                            }
                    )

                    // Upper Bound Knob
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: upperBoundOffset)
                    .gesture(
                        DragGesture()
                            .updating($dragState) { value, state, _ in
                                state = .draggingUpper
                            }
                            .onChanged { value in
                                upperBoundOffset = value.location.x
                                let newEndDate = rangeBounds.lowerBound.addingTimeInterval(Double(upperBoundOffset / geometry.size.width) * totalSeconds)
                                if newEndDate > filter.start && newEndDate <= rangeBounds.upperBound {
                                    filter.end = newEndDate
                                }
                            }
                    )

                    // Lower Bound Tooltip
                if dragState == .draggingLower {
                    Text(dateFormatter.string(from: filter.start))
                        .font(.caption)
                        .padding(5)
//                        .background(Color.black)
                        .cornerRadius(5)
                        .offset(x: lowerBoundOffset, y: 30)
                }

                    // Upper Bound Tooltip
                if dragState == .draggingUpper {
                    Text(dateFormatter.string(from: filter.end))
                        .font(.caption)
                        .padding(5)
//                        .background(Color.black)
                        .cornerRadius(5)
                        .offset(x: upperBoundOffset, y: 30)
                }
            }
            .frame(height: 50)
            .onAppear {
                lowerBoundOffset = geometry.size.width * CGFloat(lowerBoundSeconds / totalSeconds)
                upperBoundOffset = geometry.size.width * CGFloat(upperBoundSeconds / totalSeconds)
            }
        }
    }
}

#Preview {
    RangeSlider(filter: .constant(Filter()), rangeBounds: Date(timeIntervalSince1970: 0)...Date())
}
