import Foundation
import SplatDatabase
import GRDB
import Combine

class CoopDetailViewModel: ObservableObject {
    @Published var coop: Coop?
    @Published var waveResults:[CoopWaveResult] = []
    @Published var enemyResults:[CoopEnemyResult] = []
    @Published var playerResults:[CoopPlayerResult] = []
    @Published var initialized = false

    var cancelBag = Set<AnyCancellable>()
    var id: Int64 = 0

    init(id: Int64){
        self.id = id
    }

    func load() async{
        await measureTime(title: "CoopDetailViewModel \(id)") {
            let coop = try! await SplatDatabase.shared.dbQueue.read { db in
                return try Coop.fetchOne(db, key: self.id)!
            }
            try! await SplatDatabase.shared.dbQueue.read { db in
                let waveResults = try CoopWaveResult.fetchAll(db, sql: "SELECT * FROM coopWaveResult WHERE coopId = ?", arguments: [self.id])
                let enemyResults = try CoopEnemyResult.fetchAll(db, sql: "SELECT * FROM coopEnemyResult WHERE coopId = ?", arguments: [self.id])
                let playerResults = try CoopPlayerResult.fetchAll(db, sql: "SELECT * FROM coopPlayerResult WHERE coopId = ?", arguments: [self.id])
                DispatchQueue.main.async {
                    self.coop = coop
                    self.waveResults = waveResults
                    self.enemyResults = enemyResults
                    self.playerResults = playerResults
                    self.initialized = true
                }
            }
        }
    }

}

func measureTime<T>(title: String, block: () async -> T) async -> T {
    let startTime = DispatchTime.now()
    let result = await block()
    let endTime = DispatchTime.now()

    let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let milliseconds = Double(elapsedTime) / 1_000_000

    print("\(title) 执行时间：\(milliseconds) 毫秒")

    return result
}

func measureTime<T>(title: String, block: ()  -> T)  -> T {
    let startTime = DispatchTime.now()
    let result = block()
    let endTime = DispatchTime.now()

    let elapsedTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let milliseconds = Double(elapsedTime) / 1_000_000

    print("\(title) 执行时间：\(milliseconds) 毫秒")

    return result
}





