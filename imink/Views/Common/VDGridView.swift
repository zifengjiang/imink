import SwiftUI

/// 最近 500 场胜负/通关矩阵图（50 列 × 10 行，每 5 列 = 50 场为一分块）。
///
/// 直接通过 `Canvas` 同步绘制 500 个网格单元（耗时 < 0.1ms），彻底消除在 `CarouselView`
/// 分页克隆容器内因异步 `Task` 取消导致永久卡在 `Loading...` 的状态竞态；
/// 当本地尚无对应模式记录时展示结构化多语言空状态。
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

    private let count: Int = 500
    private let rowCount: Int = 10
    private let blockCount: Int = 10
    private let blockMargin: CGFloat = 2

    private var columnCount: Int {
        count / rowCount
    }

    private var normalizedCells: [VDResult] {
        let reversed = Array(data.prefix(count).reversed())
        let startIndex = max(0, count - reversed.count)
        return (0..<count).map { index in
            guard index >= startIndex else { return .disconnected }
            guard let result = reversed[index - startIndex] else { return .disconnected }
            return result ? .lose : .win
        }
    }

    private func calculateDimensions(width: CGFloat) -> (itemSize: CGFloat, height: CGFloat, lastBlockWidth: CGFloat) {
        let effectiveWidth = width > 120 ? width : 361
        let itemSize = (effectiveWidth - CGFloat(columnCount - 1) - CGFloat(blockCount - 1) * blockMargin) / CGFloat(columnCount)
        let calculatedHeight = itemSize * CGFloat(rowCount) + CGFloat(rowCount - 1)
        let colsPerBlock = CGFloat(count / rowCount / blockCount)
        let calculatedLastBlockWidth = itemSize * colsPerBlock + (colsPerBlock - 1)
        return (itemSize, calculatedHeight, calculatedLastBlockWidth)
    }

    var body: some View {
        GeometryReader { geo in
            let dims = calculateDimensions(width: geo.size.width)

            Group {
                if data.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.3x3.topleft.filled")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(isCoop ? "vd_grid_empty_coop" : "vd_grid_empty_battle")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    let cells = normalizedCells
                    let winColor = isCoop ? Color.waveDefeat : VDResult.win.color
                    let loseColor = VDResult.lose.color
                    let disconnectedColor = VDResult.disconnected.color

                    Canvas { context, _ in
                        var winPath = Path()
                        var losePath = Path()
                        var disconnectedPath = Path()

                        var itemIndex = 0
                        for column in 0..<columnCount {
                            let startX = dims.itemSize * CGFloat(column) + CGFloat(column) + CGFloat(column / 5) * blockMargin
                            for row in 0..<rowCount {
                                let startY = dims.itemSize * CGFloat(row) + CGFloat(row)
                                let rect = CGRect(x: startX, y: startY, width: dims.itemSize, height: dims.itemSize)
                                switch cells[itemIndex] {
                                case .win:
                                    winPath.addRect(rect)
                                case .lose:
                                    losePath.addRect(rect)
                                case .disconnected:
                                    disconnectedPath.addRect(rect)
                                }
                                itemIndex += 1
                            }
                        }

                        context.fill(disconnectedPath, with: .color(disconnectedColor))
                        context.fill(losePath, with: .color(loseColor))
                        context.fill(winPath, with: .color(winColor))
                    }
                }
            }
            .onAppear {
                syncBindings(with: dims)
            }
            .onChange(of: geo.size.width) { _, newWidth in
                syncBindings(with: calculateDimensions(width: newWidth))
            }
        }
    }

    private func syncBindings(with dims: (itemSize: CGFloat, height: CGFloat, lastBlockWidth: CGFloat)) {
        if abs(height - dims.height) > 0.5 {
            height = dims.height
        }
        if abs(lastBlockWidth - dims.lastBlockWidth) > 0.5 {
            lastBlockWidth = dims.lastBlockWidth
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
