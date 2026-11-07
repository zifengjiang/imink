import Foundation
import SwiftUI
import GRDB
import SplatDatabase
import Zip
import os.log
import SwiftyJSON
import Algorithms

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
