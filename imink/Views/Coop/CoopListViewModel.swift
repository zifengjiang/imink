import Foundation
import Combine
import SplatDatabase
import GRDB

@Observable
class CoopListViewModel: ObservableObject {
    var rows: [CoopListRowModel] = []
    var groupId = 0
    var activeID:String?
    var isLogin: Bool = AppUserDefaults.shared.sessionToken != nil

    private var offset: Int = 0

    private var cancelBag = Set<AnyCancellable>()

    init() {
        fetchCoops(limit: 1000, offset: 0)
    }

    private func fetchCoops(limit:Int = 30, offset: Int = 0) {
        SplatDatabase.shared.coops(limit:limit, offset)
            .catch { error -> Just<[CoopListItemInfo]> in
                return Just<[CoopListItemInfo]>([])
            }
            .map { [weak self] coops -> [CoopListRowModel] in
                guard let self = self else { return [] }
                self.offset += coops.count
                var rows = [CoopListRowModel]()
                for coop in coops {
                    if coop.GroupId != self.groupId {
                        self.groupId = Int(coop.GroupId)
                        if let row = try? SplatDatabase.shared.dbQueue.read({ db in
                            return try Row.fetchOne(db, sql: shift_card_sql, arguments: [self.groupId])
                        }) {
                            rows.append(CoopListRowModel(isDetail: false, card: try! CoopShiftCard(row: row)))
                        }
                    }
                    rows.append(CoopListRowModel(isDetail: true, coop: coop))
                }
                return rows
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRows in
                self?.rows = newRows
            }
            .store(in: &cancelBag)
    }

    func loadMore() {
//        fetchCoops(offset: self.offset)
    }
}
