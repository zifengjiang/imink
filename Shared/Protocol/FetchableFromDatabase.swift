import Foundation
import SplatDatabase
import GRDB
import Combine

protocol FetchableFromDatabase: FetchableRecord, Decodable {
    static func fetchRequest(accountId: Int, groupId: Int) -> SQLRequest<Row>
}

extension FetchableFromDatabase {
    static func fetchAll(accountId: Int = AppUserDefaults.shared.accountId, groupId: Int) -> AnyPublisher<[Self], Error>{
        ValueObservation
            .tracking { db in
                try Self.fetchAll(db, Self.fetchRequest(accountId: accountId, groupId: groupId))
            }
            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}
