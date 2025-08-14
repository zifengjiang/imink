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

    private var importProgress = DataBackupProgress()
    private var importError: DataBackupError? = nil

    private var progressCancellable: AnyCancellable?

    private var loadCount = 0
    private var fileTotalCount = 0
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

    // MARK: Import

extension DataBackup {

    func `import`(url: URL, progress: @escaping (DataBackupProgress, DataBackupError?) -> Void) {
        importProgress = DataBackupProgress()
        importError = nil

        progressCancellable = Timer.publish(every: 0.1, on: .current, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let `self` = self else {
                    return
                }

                print("progress: \(self.importProgress.value, places: 5), t: \(Date.timeIntervalSinceReferenceDate)")

                if self.importProgress.value == 1 || self.importError != nil {
                    try? self.removeTemporaryFiles()
                    self.progressCancellable?.cancel()
                }

                progress(
                    self.importProgress,
                    self.importError
                )
            }

        DispatchQueue(label: "import", attributes: .concurrent).async {
            if url.pathExtension == "zip"{
                self.importDataFromZIP(url: url)
            } else if url.pathExtension == "sqlite" || url.pathExtension == "db" {
                self.importDataFromDatabase(url: url)
            }
        }
    }

    private func importDataFromZIP(url: URL) {
        let fileManager = FileManager()
        let temporaryPath = fileManager.temporaryDirectory
        let importPath = temporaryPath.appendingPathComponent("import")
        print(SplatDatabase.shared.dbQueue.path)

        do {
                // Create import Directory
            try removeTemporaryFiles()
            try fileManager.createDirectory(at: importPath, withIntermediateDirectories: true, attributes: nil)

                // Unzip
            try Zip.unzipFile(url, destination: importPath, overwrite: true, password: nil, progress: { [weak self] value in
                self?.importProgress.unzipProgress = value
            })
            
            // 检查解压后的文件是否包含数据库文件
            let databaseFiles = findDatabaseFiles(in: importPath)
            if !databaseFiles.isEmpty {
                // 如果找到数据库文件，使用数据库导入逻辑
                if let firstDatabaseFile = databaseFiles.first {
                    self.importDataFromDatabase(url: firstDatabaseFile)
                }
                return
            }

            let battlePath = importPath.appendingPathComponent("battles")
            let battleFilePaths = try fileManager.contentsOfDirectory(
                at: battlePath,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])
                .filter { $0.pathExtension == "json" }
            importProgress.importBattlesCount = battleFilePaths.count

            let salmonRunPath = importPath.appendingPathComponent("coops")
            let salmonRunFilePaths = try fileManager.contentsOfDirectory(
                at: salmonRunPath,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])
                .filter { $0.pathExtension == "json" }
            importProgress.importJobsCount = salmonRunFilePaths.count

                // Load battle and job files
            self.fileTotalCount = battleFilePaths.count + salmonRunFilePaths.count
            self.loadCount = 0

            let batchSize = 100 // 每批处理的文件数量
            let battleFileBatches = battleFilePaths.chunks(ofCount: batchSize)
            let salmonRunFileBatches = salmonRunFilePaths.chunks(ofCount: batchSize)

            for batch in salmonRunFileBatches {
                autoreleasepool{
                    self.processSalmonRunBatch(batch)
                }
            }

            for batch in battleFileBatches {
                autoreleasepool{
                    self.processBattleBatch(batch)
                }
            }

        } catch is CocoaError {
            self.importError = .invalidDirectoryStructure
            try! removeTemporaryFiles()
        } catch let error {
            os_log("Import Error: \(error.localizedDescription)")
            self.importError = .unknownError
        }
    }

    private func processSalmonRunBatch(_ salmonRunFilePaths: ChunksOfCountCollection<[URL]>.Element){
        SplatDatabase.shared.dbQueue.customAsyncWrite { db in
            for url in salmonRunFilePaths {
                autoreleasepool {
                    self.loadCount += 1
                    self.importProgress.loadFilesProgress = Double(self.loadCount) / Double(self.fileTotalCount)
                    do {
                        let jsonData = try JSON(data: Data(contentsOf: url))
                        if try !SplatDatabase.shared.isCoopExist(id: jsonData["coopHistoryDetail"]["id"].stringValue, db: db){
                            try SplatDatabase.shared.insertCoop(json: jsonData["coopHistoryDetail"],db: db)
                            self.importProgress.importJobsProgress += 1
                        }
                    } catch {
                        print("error: \(error.localizedDescription)")
                    }
                }
            }
        } completion: { _, result in
            if case let .failure(error) = result {

                os_log("Database Error: [saveBattle] \(error.localizedDescription)")
            }
        }


    }

    private func processBattleBatch(_ battleFilePaths: ChunksOfCountCollection<[URL]>.Element){
        SplatDatabase.shared.dbQueue.customAsyncWrite { db in
            for url in battleFilePaths {
                autoreleasepool {
                    self.loadCount += 1
                    self.importProgress.loadFilesProgress = Double(self.loadCount) / Double(self.fileTotalCount)
                    do {
                        let jsonData = try JSON(data: Data(contentsOf: url))
                        if try !SplatDatabase.shared.isBattleExist(id: jsonData["vsHistoryDetail"]["id"].stringValue, db: db){
                            try SplatDatabase.shared.insertBattle(json: jsonData["vsHistoryDetail"],db: db)
                            self.importProgress.importBattlesProgress += 1
                        }
                    } catch {
                        print("error: \(error.localizedDescription)")
                    }
                }
            }
        } completion: { _, result in
            if case let .failure(error) = result {

                os_log("Database Error: [saveBattle] \(error.localizedDescription)")
            }
        }
    }
    
    private func importDataFromDatabase(url: URL) {
        do {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: url.path) else {
                self.importError = .databaseNotFound
                return
            }
            
            // 尝试访问数据库文件
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                self.importError = .databaseAccessError
                return
            }
            
            // 初始化数据库导入进度
            self.importProgress.importDatabaseTotalCount = 1
            self.importProgress.importDatabaseCurrentCount = 0
            self.importProgress.importDatabaseCoopCount = 0
            self.importProgress.importDatabaseBattleCount = 0
            
//            // 使用SplatDatabase的导入功能
//            try SplatDatabase.shared.importFromDatabaseWithConstraints(
//                sourceDbPath: url.path,
//                progress: { [weak self] progress in
//                    self?.importProgress.importDatabaseProgress = progress
//                },
//                preserveIds: false // 不保留原始ID，使用新的自增ID
//            )

            try SplatDatabase.shared.replaceDatabaseWithSource(sourceDbPath: url.path){ progress in
                self.importProgress.importDatabaseProgress = progress
            }

            // 获取导入的记录数量
            try SplatDatabase.shared.dbQueue.read { db in
                self.importProgress.importDatabaseCoopCount = try Coop.fetchCount(db)
                self.importProgress.importDatabaseBattleCount = try Battle.fetchCount(db)
            }
            
            // 标记导入完成
            self.importProgress.importDatabaseCurrentCount = 1
            self.importProgress.importDatabaseProgress = 1.0
            
        } catch {
            os_log("Database Import Error: \(error.localizedDescription)")
            self.importError = .databaseImportError
        }
    }
}

extension DataBackup {
    private func removeTemporaryFiles() throws {
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
    private func findDatabaseFiles(in directory: URL) -> [URL] {
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
                Indicators.shared.display(.init(id: UUID().uuidString, icon: .systemImage("xmark.circle.fill"), title: "导入失败",subtitle: error.localizedDescription, dismissType: .after(5),style: .error))
            } else if progress.value == 1 {
                Indicators.shared.dismiss(with: progressIndicatorId)
                Indicators.shared.display(.init(id: UUID().uuidString, icon: .systemImage("checkmark.circle.fill"), title: "导入成功",subtitle: "成功导入\(progress.count)个记录", dismissType: .after(10)))
            }
        }
    }

    static func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
