import SwiftUI
import SplatDatabase

struct BattleListRowView: View {
    let row: BattleListRowModel

    var body: some View {
        if let detail = row.detail {
            BattleListDetailItemView(detail: detail)
        } else if let card = row.card {
            BattleListShiftCardView(status: card)
        } else {
            EmptyView()
        }
    }
}

//#Preview {
//    BattleListRowView()
//}
