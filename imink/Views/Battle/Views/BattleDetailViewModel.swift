import Foundation
import SplatDatabase
import Combine

class BattleDetailViewModel: ObservableObject {
    @Published var battle: Battle?
    @Published var initialized = false

    var cancelBag = Set<AnyCancellable>()

    var id: Int64 = 0
    init(id: Int64) {
        self.id = id
    }

    func load() {
        cancelBag.removeAll()
        Battle.fetchOne(identifier: Int(self.id))
            .catch { _ -> Just<Battle?> in
                Just<Battle?>(nil)
            }
            .sink { [weak self] fetched in
                guard let self else { return }
                self.battle = fetched
                self.initialized = true
            }
            .store(in: &cancelBag)
    }
}
