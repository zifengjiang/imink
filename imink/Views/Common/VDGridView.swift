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
    @State private var drawTask: Task<Void, Never>?
    
    // 缓存计算结果
    @State private var cachedItemSize: CGFloat = 0
    @State private var cachedWidth: CGFloat = 0
    @State private var estimatedHeight: CGFloat // 预估高度，避免布局跳动
    
    init(data: [Bool?], isCoop: Bool, height: Binding<CGFloat>, lastBlockWidth: Binding<CGFloat>) {
        self.data = data
        self.isCoop = isCoop
        self._height = height
        self._lastBlockWidth = lastBlockWidth
        
        // 使用预计算的默认尺寸初始化
        let defaultWidth: CGFloat = 361
        let columnCount = 500 / 10
        let itemSize = (defaultWidth - CGFloat(columnCount - 1) - CGFloat(10 - 1) * 2) / CGFloat(columnCount)
        let defaultHeight = itemSize * CGFloat(10) + CGFloat((10 - 1))
        self._estimatedHeight = State(initialValue: defaultHeight)
    }

    private var dataSource: [VDResult] {
        // 缓存计算结果，避免重复计算
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
    
    // 添加数据变化监听
    private func shouldRedraw() -> Bool {
        // 如果数据发生变化，需要重新绘制
        return true // 这里可以根据实际需求添加更复杂的逻辑
    }

    private var columns: [GridItem] {
        (0..<10).map { _ in GridItem(.adaptive(minimum: 6), spacing: 1) }
    }

    private let count: Int = 500

    private let rowCount: Int = 10

    private let blockCount: Int = 10
    private let blockMargin: CGFloat = 2
    
    // 预计算默认尺寸，用于初始化
    private var defaultDimensions: (height: CGFloat, lastBlockWidth: CGFloat) {
        let defaultWidth: CGFloat = 361
        let itemSize = (defaultWidth - CGFloat(columnCount - 1) - CGFloat(blockCount - 1) * blockMargin) / CGFloat(columnCount)
        let height = itemSize * CGFloat(rowCount) + CGFloat((rowCount - 1))
        
        let numberOfRectanglesInEachBlock = CGFloat(count / rowCount / blockCount)
        let lastBlockWidth = itemSize * numberOfRectanglesInEachBlock + (numberOfRectanglesInEachBlock - 1)
        
        return (height, lastBlockWidth)
    }

    private var columnCount: Int {
        count / rowCount
    }
    
    // 预计算尺寸，避免重复计算
    private func calculateDimensions(width: CGFloat) -> (itemSize: CGFloat, height: CGFloat, lastBlockWidth: CGFloat) {
        let effectiveWidth = width < 300 ? 361 : width
        let itemSize = (effectiveWidth - CGFloat(columnCount - 1) - CGFloat(blockCount - 1) * blockMargin) / CGFloat(columnCount)
        let calculatedHeight = itemSize * CGFloat(rowCount) + CGFloat((rowCount - 1))
        
        let numberOfRectanglesInEachBlock = CGFloat(count / rowCount / blockCount)
        let calculatedLastBlockWidth = itemSize * numberOfRectanglesInEachBlock + (numberOfRectanglesInEachBlock - 1)
        
        return (itemSize, calculatedHeight, calculatedLastBlockWidth)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 始终显示占位符，避免大小变化
                if isLoading {
                    // 使用透明占位符保持尺寸一致
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 361, height: estimatedHeight) // 使用预估尺寸
                        .overlay(
                            LoadingView(size: 40)
                        )
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
                // 立即计算预估尺寸，避免布局跳动
                let initialDimensions = calculateDimensions(width: geo.size.width)
                estimatedHeight = initialDimensions.height
                updateDimensionsAndDraw(geo: geo)
            }
            .onChange(of: geo.size.width) { oldValue, newValue in
                // 只有当宽度真正改变时才重新计算
                if abs(newValue - cachedWidth) > 1 {
                    updateDimensionsAndDraw(geo: geo)
                }
            }
            .onDisappear {
                // 清理绘制任务
                drawTask?.cancel()
            }
        }
    }
    
    private func updateDimensionsAndDraw(geo: GeometryProxy) {
        let dimensions = calculateDimensions(width: geo.size.width)
        
        // 更新预估高度
        estimatedHeight = dimensions.height
        
        // 更新绑定值
        self.height = dimensions.height
        self.lastBlockWidth = dimensions.lastBlockWidth
        
        // 缓存当前尺寸
        cachedItemSize = dimensions.itemSize
        cachedWidth = geo.size.width
        
        // 检查是否需要重新绘制
        if shouldRedraw() {
            // 在后台加载绘制路径
            loadGridAsync(itemSize: dimensions.itemSize)
        }
    }

    private func loadGridAsync(itemSize: CGFloat) {
        // 取消之前的绘制任务
        drawTask?.cancel()
        
        // 避免重复绘制相同尺寸的路径
        if abs(itemSize - cachedItemSize) < 0.1 && !isLoading {
            return
        }
        
        // 使用 Task 来管理异步绘制
        drawTask = Task {
            // 预计算数据源，避免重复计算
            let dataSource = self.dataSource
            
            let pathWin = drawRectsOptimized(drawResult: .win, itemSize: itemSize, dataSource: dataSource)
            let pathLose = drawRectsOptimized(drawResult: .lose, itemSize: itemSize, dataSource: dataSource)
            let pathDisconnected = drawRectsOptimized(drawResult: .disconnected, itemSize: itemSize, dataSource: dataSource)
            
            // 检查任务是否被取消
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                // 使用动画平滑过渡
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.drawnPathWin = pathWin
                    self.drawnPathLose = pathLose
                    self.drawnDisconnected = pathDisconnected
                    self.isLoading = false
                }
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
    
    // 优化后的绘制方法，避免重复计算dataSource
    private func drawRectsOptimized(drawResult: VDResult, itemSize: CGFloat, dataSource: [VDResult]) -> Path {
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
