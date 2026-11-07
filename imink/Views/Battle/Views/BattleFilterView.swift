import SwiftUI
import SplatDatabase

struct BattleFilterView: View {
    @Binding var showFilterView: Bool
    @Binding var filter: Filter
    
    var onDismiss: () async -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 模式选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("对战模式")
                            .font(.splatoonFont(size: 18))
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(BattleMode.allCases.filter { $0 != .all }, id: \.rawValue) { mode in
                                Button {
                                    if filter.modes.contains(mode.rawValue) {
                                        filter.modes.remove(mode.rawValue)
                                    } else {
                                        filter.modes.insert(mode.rawValue)
                                    }
                                } label: {
                                    HStack {
                                        mode.icon
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                        Text(mode.name)
                                            .font(.splatoonFont(size: 14))
                                        Spacer()
                                    }
                                    .padding()
                                    .background(filter.modes.contains(mode.rawValue) ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    RecordStatusFilterSection(filter: $filter)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("过滤设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        filter = Filter()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showFilterView = false
                        Task {
                            await onDismiss()
                        }
                    }
                    .foregroundStyle(.accent)
                }
            }
        }
    }
}

#Preview {
    BattleFilterView(
        showFilterView: .constant(true),
        filter: .constant(Filter())
    ) {
        // onDismiss action
    }
}
