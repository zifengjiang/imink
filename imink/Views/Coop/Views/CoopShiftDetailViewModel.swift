import Foundation
import SplatDatabase
import Combine

class CoopShiftDetailViewModel: ObservableObject {

    @Published var initialized = false
    @Published var coopGroupStatus: CoopGroupStatus?
    @Published var coopWaveStatus: [CoopWaveStatus] = []
    @Published var coopWeaponStatus: [CoopWeaponStatus] = []
    @Published var coopEnemyStatus: [CoopEnemyStatus] = []

    var cancelBag = Set<AnyCancellable>()
    var id: Int = 0

    init(id: Int){
        self.id = id
    }

    func load() {
        measureTime(title: "load CoopShiftDetailViewModel") {

                //            try? SplatDatabase.shared.dbQueue.read { db in
                //                let coopGroupStatus = try CoopGroupStatus.fetchOne(db, sql: "SELECT * FROM  coop_group_status_view WHERE accountId = ? AND GroupID = ?", arguments: [AppUserDefaults.shared.accountId, id])
                //                self.coopGroupStatus = coopGroupStatus
                //            }
                //
                //            DispatchQueue.main.async {
                //                self.initialized = self.coopGroupStatus != nil
                //            }

            SplatDatabase.shared.coopGroupStatus(id: id)
                .catch { error -> Just<CoopGroupStatus?> in
                    logError(error)
                    return Just<CoopGroupStatus?>(nil)
                }
                .assign(to: \.coopGroupStatus, on: self)
                .store(in: &cancelBag)

            SplatDatabase.shared.coopWaveStatus(id: id)
                .catch { error -> Just<[CoopWaveStatus]> in
                    logError(error)
                    return Just<[CoopWaveStatus]>([])
                }
                .assign(to: \.coopWaveStatus, on: self)
                .store(in: &cancelBag)

            SplatDatabase.shared.coopWeaponStatus(id: id)
                .catch { error -> Just<[CoopWeaponStatus]> in
                    logError(error)
                    return Just<[CoopWeaponStatus]>([])
                }
                .assign(to: \.coopWeaponStatus, on: self)
                .store(in: &cancelBag)

            SplatDatabase.shared.coopEnemyStatus(id: id)
                .catch { error -> Just<[CoopEnemyStatus]> in
                    logError(error)
                    return Just<[CoopEnemyStatus]>([])
                }
                .assign(to: \.coopEnemyStatus, on: self)
                .store(in: &cancelBag)

            $coopGroupStatus
                .map{ _ in self.coopGroupStatus != nil }
                .assign(to: \.initialized, on: self)
                .store(in: &cancelBag)
        }
    }

}
