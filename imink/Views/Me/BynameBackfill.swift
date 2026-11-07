import SwiftUI
import GRDB
import SplatDatabase

// MARK: - Byname Update Progress
struct BynameUpdateProgress {
    let processed: Int
    let total: Int
    let progress: Double
    
    init(processed: Int, total: Int) {
        self.processed = processed
        self.total = total
        self.progress = total > 0 ? Double(processed) / Double(total) : 0.0
    }
}

// MARK: - Byname Update Functions
extension SettingPage {
    func updateBynameFormattedBatch() async {
        await MainActor.run {
            isUpdatingByname = true
            bynameUpdateProgress = nil
        }
        
        do {
            // 获取需要更新的记录总数
            let totalCount = try await SplatDatabase.shared.dbQueue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player WHERE bynameFormatted IS NULL") ?? 0
            }
            
            if totalCount == 0 {
                await MainActor.run {
                    isUpdatingByname = false
                }
                return
            }
            
            // 分批处理，每批处理10条记录
            let batchSize = 30
            var processedCount = 0
            
            while processedCount < totalCount {
                let currentBatchSize = min(batchSize, totalCount - processedCount)
                
                try await SplatDatabase.shared.dbQueue.write { db in
                    // 获取当前批次的记录
                    let players = try Row.fetchAll(db, sql: "SELECT id, byname FROM player WHERE bynameFormatted IS NULL LIMIT ?", arguments: [currentBatchSize])
                    
                    for player in players {
                        let playerId: Int64 = player["id"]
                        let byname: String = player["byname"]
                        
                        if let formatted = formatBynameSync(byname) {
                            let adjectiveId = getI18nId(by: formatted.adjective, db: db) ?? 0
                            let subjectId = getI18nId(by: formatted.subject, db: db) ?? 0
                            let maleFlag: UInt16 = formatted.male == nil ? 0 : (formatted.male! ? 1 : 2)
                            let bynameFormatted = PackableNumbers([adjectiveId, subjectId, maleFlag])
                            
                            try db.execute(sql: "UPDATE player SET bynameFormatted = ? WHERE id = ?", 
                                          arguments: [bynameFormatted.databaseValue, playerId])
                        }
                    }
                }
                
                processedCount += currentBatchSize
                
                // 更新进度
                await MainActor.run {
                    bynameUpdateProgress = BynameUpdateProgress(processed: processedCount, total: totalCount)
                }
                
                // 短暂延迟，避免阻塞UI
//                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            await MainActor.run {
                isUpdatingByname = false
                bynameUpdateProgress = nil
            }
            
        } catch {
            print("更新bynameFormatted时出错: \(error)")
            await MainActor.run {
                isUpdatingByname = false
                bynameUpdateProgress = nil
            }
        }
    }
    
    nonisolated func getI18nId(by key: String, db: Database) -> UInt16? {
        do {
            let row = try Row.fetchOne(db, sql: "SELECT id FROM i18n WHERE key = ?", arguments: [key])
            return row?["id"] as UInt16?
        } catch {
            print("获取i18n ID时出错: \(error)")
            return nil
        }
    }
}
