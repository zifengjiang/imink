import SwiftUI

struct CoopListDetailView: View {
    let isCoop: Bool
    let coopId: Int64?
    let shiftId: Int?

    init(isCoop: Bool, coopId: Int64? = nil, shiftId: Int? = nil) {
        self.isCoop = isCoop
        self.coopId = coopId
        self.shiftId = shiftId
    }

    var body: some View {
        VStack{
            Rectangle()
                .fill(Color.clear)
                .frame(height: 70) // To avoid "EmptyView" error

            if isCoop {
                CoopDetailView(id: coopId!)
            } else {
                CoopShiftDetailView(id: shiftId!)
            }

            Rectangle()
                .fill(Color.clear)
                .frame(height: 80) // To avoid "EmptyView" error
        }
    }
}

//#Preview {
//    CoopListDetailView()
//}
