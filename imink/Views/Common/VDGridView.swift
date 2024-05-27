import SwiftUI

struct VDGridView: View {

    enum VDResult: Int, CaseIterable {
        case win
        case lose
        case disconnected
    }

    var data: [Bool?]
    @Binding var height: CGFloat
    @Binding var lastBlockWidth: CGFloat

    private var dataSource: [VDResult] {
        let data = Array(self.data.reversed())
        let haveResultStartIndex = Int(count) - data.count
        let indexs = (0..<Int(count))
        return indexs.map { i in
            var itemStatus = VDResult.disconnected
            if i >= haveResultStartIndex {
                if let result = data[i - haveResultStartIndex] {
                    itemStatus = result ? .lose : .win
                }
            }
            return itemStatus
        }
    }

    private var columns: [GridItem] {
        (0..<10).map { _ in GridItem(.adaptive(minimum: 6), spacing: 1) }
    }

    private let count: Int = 500

    private let rowCount: Int = 10

    private let blockCount: Int = 10
    private let blockMargin: CGFloat = 2

    private var columnCount: Int {
        count / rowCount
    }

    var body: some View {
        GeometryReader { geo in
            makeGrid(geo: geo)
        }
    }

    private func makeGrid(geo: GeometryProxy) -> some View {
        let width = geo.size.width
        let itemSize = (width - CGFloat(columnCount - 1) - CGFloat(blockCount - 1) * blockMargin) / CGFloat(columnCount)
        self.height = itemSize * CGFloat(rowCount) + CGFloat((rowCount - 1))

        let numberOfRectanglesInEachBlock = CGFloat(count / rowCount / blockCount)
        self.lastBlockWidth = itemSize * numberOfRectanglesInEachBlock + (numberOfRectanglesInEachBlock - 1)

        return ZStack {
            drawRects(geo: geo, drawResult: .disconnected, itemSize: itemSize)
                .foregroundColor(VDResult.disconnected.color)
            drawRects(geo: geo, drawResult: .lose, itemSize: itemSize)
                .foregroundColor(VDResult.lose.color)
            drawRects(geo: geo, drawResult: .win, itemSize: itemSize)
                .foregroundColor(VDResult.win.color)
        }
    }

    private func drawRects(geo: GeometryProxy, drawResult: VDResult, itemSize: CGFloat) -> Path {
        Path { path in
            var itemIndex = 0
            for column in 0..<columnCount {
                for row in 0..<rowCount {
                    let result = dataSource[itemIndex]

                    if result == drawResult {
                        let startX = itemSize * CGFloat(column) + CGFloat(column) + CGFloat(column / 5) * blockMargin
                        let startY = itemSize * CGFloat(row) + CGFloat(row)

                        let rect = CGRect(x: startX, y: startY, width: itemSize, height: itemSize)
                        path.addRect(rect)
                    }

                    itemIndex += 1
                }
            }
        }
    }
}

extension VDGridView.VDResult {

    var color: Color {
        switch self {
        case .win:
            return Color.pink.opacity(0.8)
        case .lose:
            return Color.green.opacity(0.8)
        case .disconnected:
            return Color.primary.opacity(0.15)
        }
    }

}

struct VDGridView_Previews: PreviewProvider {
    @State static private var height: CGFloat = 200
    @State static private var lastBlockWidth: CGFloat = 50
    @State static private var data: [Bool?] = Array(repeating: true, count: 23) + [false,nil,false] + Array(repeating: false, count: 250)

    static var previews: some View {
        VDGridView(data: data, height: $height, lastBlockWidth: $lastBlockWidth)
            .frame(height: height)
            .previewLayout(.sizeThatFits)
            .padding()
            .onAppear {
                    // Optionally adjust initial data or theme for the preview
            }
    }
}
