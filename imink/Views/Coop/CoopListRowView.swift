import SwiftUI

struct CoopListRowView: View {
    let isCoop: Bool
    var coop: CoopListItemInfo?
    var card: CoopGroupStatus?

    init(isCoop: Bool, coop: CoopListItemInfo? = nil, card: CoopGroupStatus? = nil) {
        self.isCoop = isCoop
        self.coop = coop
        self.card = card
    }

    var body: some View {
        if isCoop {
            CoopListDetailItemView(coop: coop!)
        } else {
            CoopListShiftCardView(status: card!)
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
            return lhs.card?.startTime == rhs.card?.startTime
        }
    }
}
