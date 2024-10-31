//
//  AppState.swift
//  imink
//
//  Created by 姜锋 on 10/5/24.
//

import Foundation
import Combine
import GRDB
import SplatDatabase

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isLogin: Bool = AppUserDefaults.shared.sessionToken != nil

    @Published var salmonRunRecordsCount: Int = 0

    @Published var battleRecordsCount: Int = 0

    var viewModelDict: [Int64:CoopDetailViewModel] = [:]

    var cancelBag = Set<AnyCancellable>()

    init() {
        ValueObservation.tracking { db in
            try Coop.fetchCount(db)
        }
        .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
        .catch { error -> Just<Int> in
            logError(error)
            return Just<Int>(0)
        }
        .assign(to: \.salmonRunRecordsCount, on: self)
        .store(in: &self.cancelBag)

        ValueObservation.tracking { db in
            try Battle.fetchCount(db)
        }
        .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
        .catch { error -> Just<Int> in
            logError(error)
            return Just<Int>(0)
        }
        .assign(to: \.battleRecordsCount, on: self)
        .store(in: &self.cancelBag)
    }

}
