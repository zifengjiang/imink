import Foundation
import SplatDatabase
import Combine
import GRDB

struct CoopListRowModel:Identifiable{
    
    let isCoop: Bool
    var coop: CoopListItemInfo?
    var card: CoopShiftCard?

    var id: String {
        if isCoop {
            return "detail-\(coop!.id)"
        }
        return "card-\(card!.id)-\(card!.count)"
    }
}


