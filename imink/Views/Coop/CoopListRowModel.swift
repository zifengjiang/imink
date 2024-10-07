import Foundation
import SplatDatabase
import Combine
import GRDB

struct CoopListRowModel:Identifiable{
    
    let isCoop: Bool
    var coop: CoopListRowInfo?
    var card: CoopGroupStatus?

    var id: String {
        if isCoop {
            return "detail-\(coop!.id)"
        }
        return "card-\(card!.startTime)-\(card!.count)"
    }
}


