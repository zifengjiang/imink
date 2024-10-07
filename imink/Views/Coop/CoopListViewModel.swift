import Foundation
import SplatNet3API
import Combine
import SplatDatabase
import GRDB
import SwiftUI

class CoopListViewModel: ObservableObject {
    static let shared = CoopListViewModel()
    
    @Published var rows: [CoopListRowModel] = []
    @Published var filter: Filter = Filter()
    @Published var navigationTitle = "全部打工"

    private var cancellables: Set<AnyCancellable> = []

    var groupId = 0

    private var offset: Int = 0
    private var cancelBag = Set<AnyCancellable>()

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
                await loadCoops()
            }
        }else{
            self.rows = []
        }
    }

    func loadCoops(limit: Int = 50, offset: Int = 0, loadRecent:Bool = false) async{
        self.groupId = 0
        let rows = processCoops(await coops(filter: loadRecent ? Filter() : filter, limit: limit, offset))
        DispatchQueue.main.async {
            self.rows = rows
        }
    }

    func fetchCoops() async {
        guard AppState.shared.isLogin else { return }
        await SN3Client.shared.fetchCoops()
    }

    func cancel() {
        cancelBag.forEach { $0.cancel() }
    }

    func loadMore() async{
        let rows = processCoops(await coops(filter: filter, limit: 10, offset))
        DispatchQueue.main.async {
            self.rows.append(contentsOf: rows)
        }
    }

    private func fetchCoopsFromDatabase(limit: Int, offset: Int) -> AnyPublisher<[CoopListRowInfo], Never> {
        return coops(limit: limit, offset)
            .catch { _ in Just<[CoopListRowInfo]>([]) }
            .eraseToAnyPublisher()
    }

    private func processCoops(_ coops: [CoopListRowInfo]) -> [CoopListRowModel] {
        self.offset += coops.count
        var rows = [CoopListRowModel]()
        for coop in coops {
            if coop.GroupId != self.groupId {
                self.groupId = Int(coop.GroupId)
                if let card = try? SplatDatabase.shared.dbQueue.read({ db in
                    try CoopGroupStatus.create(from: db, identifier: (self.groupId, AppUserDefaults.shared.accountId))
                }) {
                    rows.append(CoopListRowModel(isCoop: false, card: card))
                }
            }
            rows.append(CoopListRowModel(isCoop: true, coop: coop))
        }
        return rows
    }
}
