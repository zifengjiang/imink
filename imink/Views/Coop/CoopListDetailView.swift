import SwiftUI

struct CoopListDetailView: View {
    let isCoop: Bool
    let coopId: Int64?
    let shiftId: Int?
    @Binding var navigationPath: NavigationPath

    init(isCoop: Bool, coopId: Int64? = nil, shiftId: Int? = nil, navigationPath: Binding<NavigationPath>) {
        self.isCoop = isCoop
        self.coopId = coopId
        self.shiftId = shiftId
        self._navigationPath = navigationPath
    }

    var body: some View {
        VStack{
            Rectangle()
                .fill(Color.clear)
                .frame(height: 70) // To avoid "EmptyView" error

            if isCoop {
                CoopDetailView(id: coopId!, navigationPath: $navigationPath)
            } else {
                CoopShiftDetailView(id: shiftId!, navigationPath: $navigationPath)
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
