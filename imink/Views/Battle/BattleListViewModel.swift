import Foundation
import Combine

class BattleListViewModel: ObservableObject {
    @Published var rows: [BattleListRowInfo] = []

    private var offset: Int = 0
    private var cancelBag = Set<AnyCancellable>()
    private var cancellables: Set<AnyCancellable> = []

    init() {
        AppState.shared.$isLogin
            .sink { [weak self] isLogin in
                self?.handleLoginStateChange(isLogin: isLogin)
            }
            .store(in: &cancellables)
    }

    func handleLoginStateChange(isLogin:Bool) {
        if isLogin{
            Task{
                await loadBattles()
            }
        }else{
            self.rows = []
        }
    }

    func loadBattles(limit: Int = 50, offset: Int = 0) async{
        let rows = await battles(filter: Filter(), limit: limit, offset)
        self.offset += rows.count
        DispatchQueue.main.async {
            self.rows = rows
        }
    }

    func loadMore() async{
        let rows = await battles(filter: Filter(), limit: 10, self.offset)
        self.offset += rows.count
        DispatchQueue.main.async {
            self.rows.append(contentsOf: rows)
        }
    }
}
