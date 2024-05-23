import Foundation
import SplatDatabase
import Combine
import GRDB

struct CoopListRowModel:Identifiable{
    
    let isDetail: Bool
    var coop: CoopListItemInfo?
    var card: CoopShiftCard?

    var id: String {
        if isDetail {
            return "detail-\(coop!.id)"
        }
        return "card-\(card!.id)"
    }
}


