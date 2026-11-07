    //
    //  DataBackup.swift
    //  imink
    //
    //  Created by Jone Wang on 2021/6/3.
    //

import Foundation
import Combine
import Zip
import os
import SwiftyJSON
import Algorithms

enum DataBackupError: Error {
    case unknownError
    case databaseWriteError
    case invalidDirectoryStructure
    case databaseImportError
    case databaseNotFound
    case databaseAccessError
}

extension DataBackupError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unknownError:
            return "Unknown error"
        case .databaseWriteError:
            return "Database write error"
        case .invalidDirectoryStructure:
            return "Invalid directory structure"
        case .databaseImportError:
            return "Database import error"
        case .databaseNotFound:
            return "Database file not found"
        case .databaseAccessError:
            return "Cannot access database file"
        }
    }
}

struct DataBackupProgress {
    let unzipProgressScale = 0.2
    let loadFilesProgressScale = 0.8
    var importBattlesProgressScale = 0.15
    var importJobsProgressScale = 0.05
    
    // 数据库导入相关
    var importDatabaseProgressScale = 1.0
    var importDatabaseProgress: Double = 0
    var importDatabaseTotalCount: Int = 0
    var importDatabaseCurrentCount: Int = 0
    var importDatabaseCoopCount: Int = 0
    var importDatabaseBattleCount: Int = 0

    var unzipProgress: Double = 0
    var loadFilesProgress: Double = 0
    var importBattlesProgress: Double = 0
    var importBattlesCount: Int = 0
    var importJobsProgress: Double = 0
    var importJobsCount: Int = 0

    var value: Double {
        // 如果是数据库导入，使用数据库导入进度
        if importDatabaseTotalCount > 0 {
            return importDatabaseProgress * importDatabaseProgressScale
        }
        // 否则使用原有的ZIP导入进度
        return unzipProgress * unzipProgressScale +
        loadFilesProgress * loadFilesProgressScale
    }

    var count: Int {
        if importDatabaseTotalCount > 0 {
            return importDatabaseCurrentCount
        }
        return importBattlesCount + importJobsCount
    }
}

class DataBackup {
    static let shared = DataBackup()

    var importProgress = DataBackupProgress()
    var importError: DataBackupError? = nil

    var progressCancellable: AnyCancellable?

    var loadCount = 0
    var fileTotalCount = 0
}

    // MARK: Export

extension DataBackup {

        //    func export(progress: @escaping (Bool, Double, URL?) -> Void) {
        //        progress(false, 0, nil)
        //        let queue = DispatchQueue(label: "PackingData")
        //        queue.async {
        //            let exportPath = try? self.packingData { value in
        //                DispatchQueue.main.async {
        //                    progress(false, value, nil)
        //                }
        //            }
        //            DispatchQueue.main.async {
        //                progress(true, 1, exportPath)
        //            }
        //        }
        //    }

}


extension DataBackup {
    func removeTemporaryFiles() throws {
        let fileManager = FileManager()
        let temporaryPath = fileManager.temporaryDirectory

        let importPath = temporaryPath.appendingPathComponent("import")
        if fileManager.fileExists(atPath: importPath.path) {
            try fileManager.removeItem(at: importPath)
        }

        let exportPath = temporaryPath.appendingPathComponent("imink_export")
        if fileManager.fileExists(atPath: exportPath.path) {
            try fileManager.removeItem(at: exportPath)
        }

        let zipPath = temporaryPath.appendingPathComponent("imink_export.zip")
        if fileManager.fileExists(atPath: zipPath.path) {
            try fileManager.removeItem(at: zipPath)
        }
    }
    
    /// 递归查找目录中的数据库文件
    func findDatabaseFiles(in directory: URL) -> [URL] {
        let fileManager = FileManager.default
        var databaseFiles: [URL] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            for item in contents {
                let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                
                if isDirectory {
                    // 递归搜索子目录
                    databaseFiles.append(contentsOf: findDatabaseFiles(in: item))
                } else {
                    // 检查文件扩展名
                    let pathExtension = item.pathExtension.lowercased()
                    if pathExtension == "sqlite" || pathExtension == "db" {
                        databaseFiles.append(item)
                    }
                }
            }
        } catch {
            print("Error searching for database files: \(error)")
        }
        
        return databaseFiles
    }
}

import UIKit
import SplatDatabase
import GRDB


struct ProgressTracker {
    var startTime: Date?
    var lastUpdateTime: Date?
    var progressValues: [Double] = []

    mutating func update(progress: Double) -> TimeInterval? {
        let currentTime = Date()
        if startTime == nil {
            startTime = currentTime
        }

        lastUpdateTime = currentTime
        progressValues.append(progress)

        guard progressValues.count > 1 else {
            return nil
        }

        let elapsedTime = currentTime.timeIntervalSince(startTime!)
        let completedProgress = progressValues.last!

        guard completedProgress > 0 else {
            return nil
        }

        let averageSpeed = elapsedTime / completedProgress
        let remainingTime = (1.0 - completedProgress) * averageSpeed

        return remainingTime
    }
}

extension DataBackup {
    static func `import`(url: URL) {
        let progressIndicatorId = UUID().uuidString
        Indicators.shared.display(.init(id: progressIndicatorId, title: "正在导入数据", progress: 0))

        var progressTracker = ProgressTracker()

        DataBackup.shared.import(url: url) { progress, error in
            if let remainingTime = progressTracker.update(progress: progress.value) {
                let remainingTimeString = formatTimeInterval(remainingTime)
                Indicators.shared.updateProgress(for: progressIndicatorId, progress: progress.value)
                Indicators.shared.updateSubtitle(for: progressIndicatorId, subtitle: "预计剩余时间: \(remainingTimeString)")
                // 根据导入类型显示不同的信息
                if progress.importDatabaseTotalCount > 0 {
                    // 数据库导入
                    Indicators.shared.updateExpandedText(for: progressIndicatorId, expandedText: "已导入\(Int(progress.importDatabaseCoopCount))个打工记录，\(Int(progress.importDatabaseBattleCount))个对战记录")
                } else {
                    // ZIP导入
                    Indicators.shared.updateExpandedText(for: progressIndicatorId, expandedText: "已导入\(Int(progress.importJobsProgress))个打工记录，\(Int(progress.importBattlesProgress))个对战记录")
                }
            } else {
                Indicators.shared.updateProgress(for: progressIndicatorId, progress: progress.value)
            }
            if let error = error {
                Indicators.shared.dismiss(with: progressIndicatorId)
                Toast.failure("导入失败", subtitle: error.localizedDescription, dismissAfter: 5)
            } else if progress.value == 1 {
                Indicators.shared.dismiss(with: progressIndicatorId)
                Toast.success("导入成功", subtitle: "成功导入\(progress.count)个记录", dismissAfter: 10)
            }
        }
    }

    static func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
