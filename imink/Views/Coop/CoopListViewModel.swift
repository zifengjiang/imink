import Foundation
import Combine
import SplatDatabase
import GRDB
import SwiftUI

@MainActor
class CoopListViewModel: ObservableObject {
    static let shared = CoopListViewModel()
    
    @Published var rows: [CoopListRowModel] = []
    @Published var filter: Filter = Filter()
    @Published var navigationTitle = "全部打工"
    @Published var detailViewModel:CoopDetailViewModel? = nil
    @Published var detailId:Int64? = nil
    @Published var currentCoopIsFavorite: Bool = false

    private var cancellables: Set<AnyCancellable> = []

    var groupId = 0

    private var offset: Int = 0
    private var cancelBag = Set<AnyCancellable>()

    private init() {
        AppState.shared.$isLogin
            .sink { [weak self] isLogin in
                self?.handleLoginStateChange(isLogin: isLogin)
            }
            .store(in: &cancellables)
        
        // 监听数据变化通知
        NotificationCenter.default.publisher(for: .coopDataChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadCoops()
                }
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
        let coopss:[CoopListRowInfo] = await measureTime(title: "loadCoops") {
            await coops(filter: loadRecent ? Filter() : filter, limit: limit, offset)
        }
        let rows = measureTime(title: "processCoops") {
            processCoops(coopss)
        }
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

    func loadMoreCards() async {
        do {
                // 1) 在主 actor 上读取需要的状态
            let offset = self.rows.count
            let accountId = AppUserDefaults.shared.accountId

                // 2) 传入纯值，read 闭包里不引用 self/rows
            let cards: [CoopGroupStatus] = try await SplatDatabase.shared.dbQueue.read { db in
                try CoopGroupStatus.create(from: db, identifier: (accountId, offset))
            }

                // 3) 回到主 actor（方法本身已在 MainActor），直接更新 UI 状态
            self.rows.append(contentsOf: cards.map { CoopListRowModel(isCoop: false, card: $0) })
        } catch {
            logError(error)
        }
    }

    func loadCards(limit: Int = 50, offset:Int = 0) async {
        do{
            let cards:[CoopGroupStatus] = try await SplatDatabase.shared.dbQueue.read { db in
                try CoopGroupStatus.create(from: db, identifier: (AppUserDefaults.shared.accountId, offset))
            }
            DispatchQueue.main.async {
                self.rows = cards.map { CoopListRowModel(isCoop: false, card: $0) }
            }
        }catch{
            logError(error)
        }
    }
    
    // MARK: - 收藏相关方法
    
    func toggleFavorite(for selectedRow: String?) {
        guard let rowId = selectedRow, let coop = rows.first(where: {$0.id == rowId})?.coop else { return }
        
        Task {
            do {
                if let actualCoop = try await SplatDatabase.shared.dbQueue.read({ db in
                    try Coop.fetchOne(db, key: coop.id)
                }) {
                    try actualCoop.toggleFavorite()
                    await MainActor.run {
                        self.currentCoopIsFavorite.toggle()
                    }
                }
            } catch {
                print("Error toggling favorite: \(error)")
            }
        }
    }
    
    func loadCurrentCoopFavoriteStatus(for selectedRow: String?) {
        guard let rowId = selectedRow, let coop = rows.first(where: {$0.id == rowId})?.coop else { return }
        
        Task {
            do {
                if let actualCoop = try await SplatDatabase.shared.dbQueue.read({ db in
                    try Coop.fetchOne(db, key: coop.id)
                }) {
                    await MainActor.run {
                        self.currentCoopIsFavorite = actualCoop.isFavorite
                    }
                }
            } catch {
                print("Error loading coop favorite status: \(error)")
            }
        }
    }

}
