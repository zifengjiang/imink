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

    var groupId = 0
    var isLogin: Bool = AppUserDefaults.shared.sessionToken != nil
    private var offset: Int = 0
    private var cancelBag = Set<AnyCancellable>()

    init() {
        Task{
            await loadCoops()
        }
    }

    func loadCoops(limit: Int = 50, offset: Int = 0, loadRecent:Bool = false) async{
        self.groupId = 0
        print("load_coops")

        let rows = processCoops(await coops(filter: loadRecent ? Filter() : filter, limit: limit, offset))
        DispatchQueue.main.async {
            self.rows = rows
        }
    }

    func fetchCoops() async {
        await SN3Client.shared.fetchCoops()
//        await loadCoops()
    }

    func cancel() {
        cancelBag.forEach { $0.cancel() }
    }

    func loadMore() async{
//        coops(filter:filter, limit: 10, offset)
//            .catch { _ in Just<[CoopListItemInfo]>([]) }
//            .map { [weak self] coops in
//                self?.processCoops(coops) ?? []
//            }
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] newRows in
//                withAnimation {
//                    self?.rows.append(contentsOf: newRows)
//                }
//            }
//            .store(in: &cancelBag)
        let rows = processCoops(await coops(filter: filter, limit: 10, offset))
        DispatchQueue.main.async {
            self.rows.append(contentsOf: rows)
        }
    }

    private func fetchCoopsFromDatabase(limit: Int, offset: Int) -> AnyPublisher<[CoopListItemInfo], Never> {
        return coops(limit: limit, offset)
            .catch { _ in Just<[CoopListItemInfo]>([]) }
            .eraseToAnyPublisher()
    }

    private func processCoops(_ coops: [CoopListItemInfo]) -> [CoopListRowModel] {
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
