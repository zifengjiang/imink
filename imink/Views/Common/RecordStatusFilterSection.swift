import SwiftUI
import SplatDatabase

/// 对战 / 打工列表共用的「记录状态」筛选项。
struct RecordStatusFilterSection: View {
    @Binding var filter: Filter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("记录状态")
                .font(.splatoonFont(size: 18))

            Toggle("只显示收藏", isOn: $filter.showOnlyFavorites)

            HStack {
                Text("显示模式:")
                    .font(.splatoonFont(size: 14))
                Spacer()
                Picker("显示模式", selection: $filter.visibility) {
                    ForEach(Filter.RecordVisibility.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
}
