import SwiftUI

struct CoopListRowView: View {
    let row: CoopListRowModel


    var body: some View {
        if row.isCoop, let coop = row.coop {
            CoopListDetailItemView(coop: coop)
        } else if let card = row.card{
            CoopListShiftCardView(status: card)
        } else {
            EmptyView()
        }
    }
}

extension CoopListRowView:Equatable {
    static func == (lhs: CoopListRowView, rhs: CoopListRowView) -> Bool {
        if lhs.row.isCoop != rhs.row.isCoop {
            return false
        }
        if lhs.row.isCoop {
            return lhs.row.coop?.id == rhs.row.coop?.id
        } else {
            return lhs.row.card?.startTime == rhs.row.card?.startTime
        }
    }
}
