import Foundation
import SplatDatabase
import Combine
import Algorithms

class CoopShiftDetailViewModel: ObservableObject {
    @Published var initialized = false
    @Published var coopGroupStatus: CoopGroupStatus?
    @Published var coopWaveStatus: [[CoopWaveStatus]] = []
    @Published var coopWeaponStatus: [CoopWeaponStatus] = []
    @Published var coopEnemyStatus: [CoopEnemyStatus] = []
    @Published var coopPlayerStatus: [CoopPlayerStatus] = []

    var id: Int = 0

    init(id: Int){
        self.id = id
    }


    func load() async {
        SplatDatabase.shared.dbQueue.asyncRead { dbResult in
            do {
                let db = try dbResult.get()
                let identifier = (self.id, AppUserDefaults.shared.accountId)

                let coopGroupStatus = try CoopGroupStatus.create(from: db, identifier: identifier)
                let coopWaveStatus: [CoopWaveStatus] = try CoopWaveStatus.create(from: db, identifier: identifier)
                let coopWaveStatusGrouped = Array(coopWaveStatus.grouped(by: { $0.eventWaveGroup ?? "nil" }).values.sorted {
                    guard let l = $0.first?.eventWaveGroup?.order, let r = $1.first?.eventWaveGroup?.order else {
                        return $0.first?.eventWaveGroup?.order == nil
                    }
                    return l > r
                })
                let coopWeaponStatus = try CoopWeaponStatus.create(from: db, identifier: identifier).sorted { $0.count > $1.count }
                let coopEnemyStatus = try CoopEnemyStatus.create(from: db, identifier: identifier).sorted{$0.nameId.order < $1.nameId.order}
                let coopPlayerStatus = try CoopPlayerStatus.create(from: db, identifier: identifier)

                DispatchQueue.main.async {
                    self.coopGroupStatus = coopGroupStatus
                    self.coopWaveStatus = coopWaveStatusGrouped
                    self.coopWeaponStatus = coopWeaponStatus
                    self.coopEnemyStatus = coopEnemyStatus
                    self.coopPlayerStatus = coopPlayerStatus
                    self.initialized = true
                }
            } catch {
                logError(error)
            }
        }
    }

}
