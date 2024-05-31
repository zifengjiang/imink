import Foundation
import Combine
import SplatDatabase
import GRDB
import SwiftUI

@Observable
class CoopListViewModel: ObservableObject {
    static let shared = CoopListViewModel()

    var rows: [CoopListRowModel] = []
    var groupId = 0
    var activeID: String?
    var isLogin: Bool = AppUserDefaults.shared.sessionToken != nil
    private var offset: Int = 0
    private var cancelBag = Set<AnyCancellable>()

    init() {
        fetchCoops()
    }

    func fetchCoops(limit: Int = 50, offset: Int = 0) {
        self.groupId = 0
        fetchCoopsFromDatabase(limit: limit, offset: offset)
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

    func cancel() {
        cancelBag.forEach { $0.cancel() }
    }

    func loadMore() {
        fetchCoopsFromDatabase(limit: 10, offset: offset)
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
        return SplatDatabase.shared.coops(limit: limit, offset)
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
