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

    var groupId = 0
    var isLogin: Bool = AppUserDefaults.shared.sessionToken != nil
    private var offset: Int = 0
    private var cancelBag = Set<AnyCancellable>()

    init() {
        loadCoops()
    }

    func loadCoops(limit: Int = 50, offset: Int = 0) {
        self.groupId = 0
        coops(filter: filter, limit: limit, offset)
            .catch { _ in Just<[CoopListItemInfo]>([]) }
            .map { [weak self] coops in
                self?.processCoops(coops) ?? []
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRows in
                withAnimation {
                    self?.rows = newRows
                }
            }
            .store(in: &cancelBag)
    }

    func fetchCoops() async {
        await SN3Client.shared.fetchCoops()
    }

    func cancel() {
        cancelBag.forEach { $0.cancel() }
    }

    func loadMore() {
        coops(filter:filter, limit: 10, offset)
            .catch { _ in Just<[CoopListItemInfo]>([]) }
            .map { [weak self] coops in
                self?.processCoops(coops) ?? []
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRows in
                withAnimation {
                    self?.rows.append(contentsOf: newRows)
                }
            }
            .store(in: &cancelBag)
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
                    try CoopShiftCard.create(from: db, identifier: (self.groupId, AppUserDefaults.shared.accountId))
                }) {
                    rows.append(CoopListRowModel(isCoop: false, card: card))
                }
            }
            rows.append(CoopListRowModel(isCoop: true, coop: coop))
        }
        return rows
    }
}
