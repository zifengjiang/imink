import Foundation
import Combine
import SplatDatabase
import GRDB
import SwiftUI

@Observable
class CoopListViewModel: ObservableObject {
    var rows: [CoopListRowModel] = []
    var groupId = 0
    var activeID:String?
    var isLogin: Bool = AppUserDefaults.shared.sessionToken != nil
    private var offset: Int = 0

    private var cancelBag = Set<AnyCancellable>()

    init() {
        fetchCoops(limit: 300, offset: 0)
    }

    private func fetchCoops(limit:Int = 10, offset: Int = 0) {
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
                            return try Row.fetchOne(db, sql: shift_card_sql, arguments: [self.groupId, AppUserDefaults.shared.accountId])
                        }), let id:Int = row["id"] {
                            var card = try! CoopShiftCard(row: row)
                            card.weapons = SplatDatabase.shared.shiftWeapons(groupId: id)
                            rows.append(CoopListRowModel(isCoop: false, card: card))
                        }
                    }
                    rows.append(CoopListRowModel(isCoop: true, coop: coop))
                }
                return rows
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRows in
                withAnimation {
                    self?.rows = newRows
                }
            }
            .store(in: &cancelBag)
//        let coops:[CoopListItemInfo] = SplatDatabase.shared.coops(limit: limit, offset)
//        self.offset += coops.count
//        for coop in coops {
//            if coop.GroupId != self.groupId {
//                self.groupId = Int(coop.GroupId)
//                if let row = try? SplatDatabase.shared.dbQueue.read({ db in
//                    return try Row.fetchOne(db, sql: shift_card_sql, arguments: [self.groupId])
//                }) {
//                    withAnimation {
//                        rows.append(CoopListRowModel(isCoop: false, card: try! CoopShiftCard(row: row)))
//                    }
//                }
//            }
//            withAnimation {
//                rows.append(CoopListRowModel(isCoop: true, coop: coop))
//            }
//        }
    }

    func loadMore() {
        print("loadMore")
//        fetchCoops(limit: 30, offset: offset)

        SplatDatabase.shared.coops(limit: 10, offset)
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
                            rows.append(CoopListRowModel(isCoop: false, card: try! CoopShiftCard(row: row)))
                        }
                    }
                    rows.append(CoopListRowModel(isCoop: true, coop: coop))
                }
                return rows
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRows in
                withAnimation {
                    self?.rows.append(contentsOf: newRows)
                }
            }
            .store(in: &cancelBag)
    }
}
