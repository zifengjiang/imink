import SwiftUI

/// 打工翻页容器的单页内容。
///
/// 之前用上下两个固定高度的透明方块来"占位"，
/// 会让滚动区域超出可视范围，内容顶到导航栏下方、底部被 Tab 栏遮住；
/// 现在直接把页面交给内部视图，由各自的 ScrollView + 安全区处理留白。
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
        Group {
            if isCoop, let coopId {
                CoopDetailView(id: coopId, navigationPath: $navigationPath)
            } else if let shiftId {
                CoopShiftDetailView(id: shiftId, navigationPath: $navigationPath)
            } else {
                Color.clear
            }
        }
    }
}

//#Preview {
//    CoopListDetailView()
//}
