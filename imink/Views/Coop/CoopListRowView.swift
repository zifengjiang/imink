import SwiftUI

struct CoopListRowView: View {
    let isCoop: Bool
    var coop: CoopListItemInfo?
    var card: CoopShiftCard?

    init(isCoop: Bool, coop: CoopListItemInfo? = nil, card: CoopShiftCard? = nil) {
        self.isCoop = isCoop
        self.coop = coop
        self.card = card
    }

    var body: some View {
        if isCoop {
            CoopListDetailItemView(coop: coop!)
        } else {
            CoopListShiftCardView(card: card!)
//            EmptyView()
        }
    }
}

extension CoopListRowView:Equatable {
    static func == (lhs: CoopListRowView, rhs: CoopListRowView) -> Bool {
        if lhs.isCoop != rhs.isCoop {
            return false
        }
        if lhs.isCoop {
            return lhs.coop?.id == rhs.coop?.id
        } else {
            return lhs.card?.id == rhs.card?.id
        }
    }
}
