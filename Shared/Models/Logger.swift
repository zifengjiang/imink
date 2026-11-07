import Foundation
import os.log

let logger = Logger(subsystem: "com.jiangfeng.imink", category: "general")

/// 统一错误日志。
///
/// 消息标记为 `.public`：默认的 `<private>` 会让设备日志里只剩占位符，
/// 真机排障时拿不到任何有效信息。这里只输出错误描述与出错位置，不含用户数据。
func logError(_ error: Error, function: String = #function, file: String = #file, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent

    // Swift Error 的字符串描述比 localizedDescription 更具体（后者对未实现
    // LocalizedError 的枚举会退化成「The operation couldn't be completed」）
    logger.error(
        "Error: \(String(describing: error), privacy: .public) | localized: \(error.localizedDescription, privacy: .public) | \(fileName, privacy: .public):\(line) in \(function, privacy: .public)"
    )
}
