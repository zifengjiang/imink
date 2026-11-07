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

    func load() {
        cancelBag = Set<AnyCancellable>()
        initialized = false

        CoopWaveResult.fetchAll(identifier: id)
            .catch { error -> Just<[CoopWaveResult]> in
                return Just<[CoopWaveResult]>([])
            }
            .assign(to: \.waveResults, on: self)
            .store(in: &cancelBag)

        CoopEnemyResult.fetchAll(identifier: id)
            .catch { error -> Just<[CoopEnemyResult]> in
                return Just<[CoopEnemyResult]>([])
            }
            .assign(to: \.enemyResults, on: self)
            .store(in: &cancelBag)

        CoopPlayerResult.fetchAll(identifier: id)
            .catch { error -> Just<[CoopPlayerResult]> in
                return Just<[CoopPlayerResult]>([])
            }
            .assign(to: \.playerResults, on: self)
            .store(in: &cancelBag)

        Coop.fetchOne(identifier: id)
            .catch { error -> Just<Coop?> in
                return Just<Coop?>(nil)
            }
            .assign(to: \.coop, on: self)
            .store(in: &cancelBag)

        $coop
            .map{ _ in self.coop != nil }
            .assign(to: \.initialized, on: self)
            .store(in: &cancelBag)
    }
}

