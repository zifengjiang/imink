import Foundation
import SplatDatabase
import Combine

class BattleDetailViewModel: ObservableObject {
    @Published var battle: Battle?
    @Published var initialized = false

    var cancelBag = Set<AnyCancellable>()

    var id:Int64 = 0
    init(id: Int64){
        self.id = id
    }

    func load() {
        Battle.fetchOne(identifier: (Int)(self.id))
            .catch { error -> Just<Battle?> in
                return Just<Battle?>(nil)
            }
            .assign(to: \.battle, on: self)
            .store(in: &cancelBag)
        $battle
            .map{_ in
                self.battle != nil
            }
            .assign(to: \.initialized, on: self)
            .store(in: &cancelBag)
    }
}
