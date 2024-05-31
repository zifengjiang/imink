import Foundation
import SplatDatabase
import GRDB
import Combine


//extension PreComputable {
//    static func fetch(identifier: Identifier) -> AnyPublisher<Self?, Error>{
//        ValueObservation
//            .tracking { db in
//                try Self.create(from: db, identifier: identifier)
//            }
//            .publisher(in: SplatDatabase.shared.dbQueue, scheduling: .immediate)
//            .eraseToAnyPublisher()
//    }
//}


