import SwiftUI

struct CoopListRowView: View {
    let row: CoopListRowModel

    var body: some View {
        if let detail = row.detail {
            CoopListDetailItemView(coop: detail)
        } else if let card = row.card {
            CoopListShiftCardView(status: card)
        } else {
            EmptyView()
        }
    }
}

extension CoopListRowView: Equatable {
    static func == (lhs: CoopListRowView, rhs: CoopListRowView) -> Bool {
        lhs.row == rhs.row
    }
}
