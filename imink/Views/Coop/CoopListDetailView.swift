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
        if isCoop {
            CoopDetailView(id: coopId!)
        } else {
            CoopShiftDetailView(id: shiftId!)
        }
    }
}

//#Preview {
//    CoopListDetailView()
//}
