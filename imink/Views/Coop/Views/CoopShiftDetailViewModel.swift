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
    @Published var allInitialized:[Bool] = [false,false,false,false]

    var cancelBag = Set<AnyCancellable>()
    var id: Int = 0

    init(id: Int){
        self.id = id
    }

    func load() {
        measureTime(title: "load CoopShiftDetailViewModel") {

            CoopGroupStatus.fetchOne(identifier: (id, AppUserDefaults.shared.accountId))
                .catch { error -> Just<CoopGroupStatus?> in
                    logError(error)
                    return Just<CoopGroupStatus?>(nil)
                }
                .map{ status in
                    self.allInitialized[0] = status != nil
                    return status
                }
                .assign(to: \.coopGroupStatus, on: self)
                .store(in: &cancelBag)

            CoopWaveStatus.fetchAll(groupId: id)
                .catch { error -> Just<[CoopWaveStatus]> in
                    logError(error)
                    return Just<[CoopWaveStatus]>([])
                }
                .map{ status in
                    self.allInitialized[1] = status.count > 0
                    return Array(status.grouped(by: { $0.eventWaveGroup ?? "nil" }).values.sorted {
                        guard let l = $0.first?.eventWaveGroup?.order, let r = $1.first?.eventWaveGroup?.order else {
                            return $0.first?.eventWaveGroup?.order == nil
                        }
                        return l > r
                    })
                }
                .assign(to: \.coopWaveStatus, on: self)
                .store(in: &cancelBag)

            CoopWeaponStatus.fetchAll(groupId: id)
                .catch { error -> Just<[CoopWeaponStatus]> in
                    logError(error)
                    return Just<[CoopWeaponStatus]>([])
                }
                .map{ status in
                    self.allInitialized[2] = status.count > 0
                    return status.sorted{$0.count > $1.count}
                }
                .assign(to: \.coopWeaponStatus, on: self)
                .store(in: &cancelBag)

            CoopEnemyStatus.fetchAll(groupId: id)
                .catch { error -> Just<[CoopEnemyStatus]> in
                    logError(error)
                    return Just<[CoopEnemyStatus]>([])
                }
                .map{ status in
                    self.allInitialized[3] = status.count > 0
                    return status.sorted{$0.nameId.order < $1.nameId.order}
                }
                .assign(to: \.coopEnemyStatus, on: self)
                .store(in: &cancelBag)

            CoopPlayerStatus.fetchAll(identifier: (id,AppUserDefaults.shared.accountId))
                .catch { error -> Just<[CoopPlayerStatus]> in
                    logError(error)
                    return Just<[CoopPlayerStatus]>([])
                }
                .assign(to: \.coopPlayerStatus, on: self)
                .store(in: &cancelBag)

            $allInitialized
                .map{ $0.allSatisfy{ $0 } }
                .assign(to: \.initialized, on: self)
                .store(in: &cancelBag)
        }
    }

}
