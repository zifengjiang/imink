import Foundation
import SplatDatabase
import Combine
import GRDB
import os

class HomeViewModel: ObservableObject {
    
    @Published var totalCoop: Int = 0
    @Published var totalBattle: Int = 0
    @Published var last500Battle: [Bool?] = []
    @Published var last500Coop: [Bool?] = []

    private var cancelBag = Set<AnyCancellable>()

    init() {
        updateStatus()
    }

    func updateStatus() {
        cancelBag = Set<AnyCancellable>()

        SplatDatabase.shared.totalCoopCount()
            .catch { error -> Just<Int> in
                os_log("Database Error: [totalCount] \(error.localizedDescription)")
                return Just<Int>(0)
            }
            .assign(to: \.totalCoop, on: self)
            .store(in: &cancelBag)

        SplatDatabase.shared.totalBattleCount()
            .catch { error -> Just<Int> in
                os_log("Database Error: [totalCount] \(error.localizedDescription)")
                return Just<Int>(0)
            }
            .assign(to: \.totalBattle, on: self)
            .store(in: &cancelBag)

        $totalCoop
            .map{ _ in SplatDatabase.shared.fetchLast500(isCoop:true) }
            .assign(to: \.last500Coop, on: self)
            .store(in: &cancelBag)

        $totalBattle
            .map{ _ in SplatDatabase.shared.fetchLast500(isCoop:false) }
            .assign(to: \.last500Battle, on: self)
            .store(in: &cancelBag)
    }
}

extension SplatDatabase {
    func fetchLast500(isCoop:Bool) -> [Bool?] {
        return try! dbQueue.read { db in
            var rows: [Row]
            if isCoop{
                rows = try! SQL.last_500_coop(accountId: 1).request.fetchAll(db)
            }else{
                rows = try! SQL.last_500_battle(accountId: 1).request.fetchAll(db)
            }
            return rows.map { row in
                if let result = row["result"] as Bool? {
                    return result
                }
                return nil
            }
        }
    }

    func totalCoopCount() -> AnyPublisher<Int, Error> {
        return ValueObservation
            .tracking(
                Coop
                    .filter(sql: "accountId = ?", arguments: [1])
                    .fetchCount
            )
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func totalBattleCount() -> AnyPublisher<Int, Error> {
        return ValueObservation
            .tracking(
                Battle
                    .filter(sql: "accountId = ?", arguments: [1])
                    .fetchCount
            )
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}
