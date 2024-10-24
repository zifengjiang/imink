import Foundation
import Combine

class BattleListViewModel: ObservableObject {
    static let shared = BattleListViewModel()

    @Published var rows: [BattleListRowModel] = []
    @Published var navigationTitle = "全部对战"
    @Published var filter = Filter()

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
        let rows = await battles(filter: self.filter, limit: limit, offset)
            .map{
                BattleListRowModel(isBattle: true, battle: $0,card: nil)
            }
        self.offset += rows.count
        DispatchQueue.main.async {
            self.rows = rows
        }
    }

    func loadMore() async{
        let rows = await battles(filter: self.filter, limit: 10, self.offset)
            .map{
                BattleListRowModel(isBattle: true, battle: $0,card: nil)
            }
        self.offset += rows.count
        DispatchQueue.main.async {
            self.rows.append(contentsOf: rows)
        }
    }
}
