import SwiftUI

struct VDGridView: View {

    enum VDResult: Int, CaseIterable {
        case win
        case lose
        case disconnected
    }

    var data: [Bool?]
    var isCoop: Bool
    @Binding var height: CGFloat
    @Binding var lastBlockWidth: CGFloat

    @State private var isLoading: Bool = true
    @State private var drawnPathWin: Path?
    @State private var drawnPathLose: Path?
    @State private var drawnDisconnected: Path?

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
            ZStack {
                if isLoading {
                    LoadingView(size: 40)
                    .frame(width: 361,alignment: .center)
                } else if let pathWin = drawnPathWin, let pathLose = drawnPathLose, let pathDisconnected = drawnDisconnected {
                    pathDisconnected
                        .foregroundColor(VDResult.disconnected.color)
                    pathLose
                        .foregroundColor(VDResult.lose.color)
                    pathWin
                        .foregroundColor(isCoop ? Color.waveDefeat : VDResult.win.color)
                }
            }
            .onAppear {
                    // 计算需要的数据并传递
                let width:CGFloat = geo.size.width
                let itemSize = (width - CGFloat(columnCount - 1) - CGFloat(blockCount - 1) * blockMargin) / CGFloat(columnCount)
                self.height = itemSize * CGFloat(rowCount) + CGFloat((rowCount - 1))

                let numberOfRectanglesInEachBlock = CGFloat(count / rowCount / blockCount)
                self.lastBlockWidth = itemSize * numberOfRectanglesInEachBlock + (numberOfRectanglesInEachBlock - 1)

                    // 在后台加载绘制路径
                loadGridAsync(itemSize: itemSize)
            }
            .onChange(of: geo.size.width) { oldValue, newValue in
                let width:CGFloat = geo.size.width < 300 ? 361 : geo.size.width
                let itemSize = (width - CGFloat(columnCount - 1) - CGFloat(blockCount - 1) * blockMargin) / CGFloat(columnCount)
                self.height = itemSize * CGFloat(rowCount) + CGFloat((rowCount - 1))

                let numberOfRectanglesInEachBlock = CGFloat(count / rowCount / blockCount)
                self.lastBlockWidth = itemSize * numberOfRectanglesInEachBlock + (numberOfRectanglesInEachBlock - 1)

                    // 在后台加载绘制路径
                loadGridAsync(itemSize: itemSize)
            }
        }
    }

    private func loadGridAsync(itemSize: CGFloat) {
        DispatchQueue.global(qos: .userInitiated).async {
            let pathWin = drawRects(drawResult: .win, itemSize: itemSize)
            let pathLose = drawRects(drawResult: .lose, itemSize: itemSize)
            let pathDisconnected = drawRects(drawResult: .disconnected, itemSize: itemSize)
            DispatchQueue.main.async {
                self.drawnPathWin = pathWin
                self.drawnPathLose = pathLose
                self.drawnDisconnected = pathDisconnected
                self.isLoading = false
            }
        }
    }

    private func makeGrid(geo: GeometryProxy) -> some View {
        let width = geo.size.width
        let itemSize = (width - CGFloat(columnCount - 1) - CGFloat(blockCount - 1) * blockMargin) / CGFloat(columnCount)
        self.height = itemSize * CGFloat(rowCount) + CGFloat((rowCount - 1))

        let numberOfRectanglesInEachBlock = CGFloat(count / rowCount / blockCount)
        self.lastBlockWidth = itemSize * numberOfRectanglesInEachBlock + (numberOfRectanglesInEachBlock - 1)

        return ZStack {
            drawRects(drawResult: .disconnected, itemSize: itemSize)
                .foregroundColor(VDResult.disconnected.color)
            drawRects(drawResult: .lose, itemSize: itemSize)
                .foregroundColor(VDResult.lose.color)
            drawRects(drawResult: .win, itemSize: itemSize)
                .foregroundColor(isCoop ? Color.waveDefeat : VDResult.win.color)
        }
    }

    private func drawRects(drawResult: VDResult, itemSize: CGFloat) -> Path {
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
            return Color.waveClear
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
        VDGridView(data: data, isCoop:true, height: $height, lastBlockWidth: $lastBlockWidth)
            .frame(height: height)
            .previewLayout(.sizeThatFits)
            .padding()
            .onAppear {
                    // Optionally adjust initial data or theme for the preview
            }
    }
}
