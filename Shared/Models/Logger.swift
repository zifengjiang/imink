import Foundation
import os.log

let logger = Logger(subsystem: "com.jiangfeng.imink", category: "general")

func logError(_ error: Error, function: String = #function, file: String = #file, line: Int = #line) {
    let timestamp = Date()
    let fileName = (file as NSString).lastPathComponent
    let message = "Error: \(error.localizedDescription) at \(fileName):\(line) in \(function) on \(timestamp)"
    logger.error("\(message)")
}
