import SwiftUI

extension View {
    func asUIImage(size: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage {
        let controller = UIHostingController(rootView: self)
        controller.view.bounds = CGRect(origin: .zero, size: size)

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)

        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}


extension View {
        /// 将视图渲染为 UIImage 后存储
    func captureAsUIImage(size: CGSize, scale: CGFloat = UIScreen.main.scale, completion: @escaping (UIImage?) -> Void) -> some View {
        modifier(CaptureAsUIImageModifier(size: size, scale: scale, completion: completion))
    }
}

struct CaptureAsUIImageModifier: ViewModifier {
    let size: CGSize
    let scale: CGFloat
    let completion: (UIImage?) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                    let image = content.asUIImage(size: size, scale: scale)
                    completion(image)
            }
    }
}

// MARK: - 耗时统计

/// 统计一段异步逻辑的耗时并写入日志，便于排查列表/查询性能。
func measureTime<T>(title: String, block: () async -> T) async -> T {
    let startTime = DispatchTime.now()
    let result = await block()
    logElapsedTime(title: title, since: startTime)
    return result
}

/// 统计一段同步逻辑的耗时并写入日志。
func measureTime<T>(title: String, block: () -> T) -> T {
    let startTime = DispatchTime.now()
    let result = block()
    logElapsedTime(title: title, since: startTime)
    return result
}

private func logElapsedTime(title: String, since startTime: DispatchTime) {
    let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
    let milliseconds = Double(elapsedNanoseconds) / 1_000_000
    logger.debug("\(title, privacy: .public) 执行时间：\(milliseconds, privacy: .public) 毫秒")
}

// MARK: - 占比计算

extension Collection where Element: BinaryInteger {
    /// 把整数序列归一化为占比序列；总和为 0 时返回全 0。
    func toPercentages() -> [Double] {
        let total = reduce(0.0) { $0 + Double($1) }
        guard total > 0 else {
            return Array(repeating: 0, count: count)
        }
        return map { Double($0) / total }
    }
}

extension Collection where Element == Double {
    /// 把浮点序列归一化为占比序列；总和为 0 时返回全 0。
    func toPercentages() -> [Double] {
        let total = reduce(0.0, +)
        guard total > 0 else {
            return Array(repeating: 0, count: count)
        }
        return map { $0 / total }
    }
}

/// 计算一组涂地点数 / 占比数据的显示比例。
///
/// 优先使用接口已返回的 `ratios`，缺失时回退到用 `scores` 归一化。
func normalizedRatios(scores: [Int64], ratios: [Double], count: Int) -> [Double] {
    if ratios.isEmpty && scores.isEmpty {
        return Array(repeating: 0, count: count)
    }
    return ratios.isEmpty ? scores.toPercentages() : ratios.toPercentages()
}
