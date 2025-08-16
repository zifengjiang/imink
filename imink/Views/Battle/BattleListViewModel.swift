import Foundation
import Combine
import SplatDatabase
import GRDB
import SwiftUI

@MainActor
class BattleListViewModel: ObservableObject {
    static let shared = BattleListViewModel()

    @Published var rows: [BattleListRowModel] = []
    @Published var navigationTitle = "全部对战"
    @Published var filter = Filter()

    private var offset: Int = 0
    private var cancelBag = Set<AnyCancellable>()
    private var cancellables: Set<AnyCancellable> = []

    var groupId = 0

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
        self.groupId = 0
        let battles:[BattleListRowInfo] = await measureTime(title: "loadBattles") {
            await BattleListRowInfo.battles(filter: self.filter, limit: limit, offset)
        }
        let rows = measureTime(title: "processBattles") {
            processBattles(battles)
        }
        DispatchQueue.main.async {
            self.rows = rows
        }
    }

    func loadMore() async{
        let rows = processBattles(await BattleListRowInfo.battles(filter: self.filter, limit: 10, self.offset))
        DispatchQueue.main.async {
            self.rows.append(contentsOf: rows)
        }
    }

    func fetchBattles() async{
        guard AppState.shared.isLogin else { return }
        await SN3Client.shared.fetchBattles()
    }

    func cancel() {
        cancelBag.forEach { $0.cancel() }
    }

    private func processBattles(_ battles: [BattleListRowInfo]) -> [BattleListRowModel] {
        self.offset += battles.count
        var rows = [BattleListRowModel]()
        for battle in battles {
            if battle.GroupId != self.groupId {
                self.groupId = Int(battle.GroupId)
                if let card = try? SplatDatabase.shared.dbQueue.read({ db in
                    try BattleGroupStatus.create(from: db, identifier: (self.groupId, AppUserDefaults.shared.accountId))
                }) {
                    rows.append(BattleListRowModel(isBattle: false, battle: nil, card: card))
                }
            }
            rows.append(BattleListRowModel(isBattle: true, battle: battle, card: nil))
        }
        return rows
    }

    func loadMoreCards() async {
        do {
                // 1) 在主 actor 上读取需要的状态
            let offset = self.rows.count
            let accountId = AppUserDefaults.shared.accountId

                // 2) 传入纯值，read 闭包里不引用 self/rows
            let cards: [BattleGroupStatus] = try await SplatDatabase.shared.dbQueue.read { db in
                try BattleGroupStatus.create(from: db, identifier: (accountId, offset))
            }

                // 3) 回到主 actor（方法本身已在 MainActor），直接更新 UI 状态
            self.rows.append(contentsOf: cards.map { BattleListRowModel(isBattle: false, battle: nil, card: $0) })
        } catch {
            logError(error)
        }
    }

    func loadCards(limit: Int = 50, offset:Int = 0) async {
        do{
            let cards:[BattleGroupStatus] = try await SplatDatabase.shared.dbQueue.read { db in
                try BattleGroupStatus.create(from: db, identifier: (AppUserDefaults.shared.accountId, offset))
            }
            DispatchQueue.main.async {
                self.rows = cards.map { BattleListRowModel(isBattle: false, battle: nil, card: $0) }
            }
        }catch{
            logError(error)
        }
    }
}
