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
                    
                    // 记录状态过滤
                    VStack(alignment: .leading, spacing: 12) {
                        Text("记录状态")
                            .font(.splatoonFont(size: 18))
                        
                        Toggle("只显示收藏", isOn: $filter.showOnlyFavorites)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("显示模式:")
                                .font(.splatoonFont(size: 14))
                            
                            Picker("显示模式", selection: Binding(
                                get: {
                                    if filter.showDeleted && !filter.showOnlyActive {
                                        return 1 // 只显示已删除
                                    } else if filter.showDeleted && filter.showOnlyActive {
                                        return 2 // 显示全部
                                    } else {
                                        return 0 // 只显示活跃
                                    }
                                },
                                set: { value in
                                    switch value {
                                    case 0: // 只显示活跃
                                        filter.showOnlyActive = true
                                        filter.showDeleted = false
                                    case 1: // 只显示已删除
                                        filter.showOnlyActive = false
                                        filter.showDeleted = true
                                    case 2: // 显示全部
                                        filter.showOnlyActive = true
                                        filter.showDeleted = true
                                    default:
                                        break
                                    }
                                }
                            )) {
                                Text("活跃记录").tag(0)
                                Text("已删除").tag(1)
                                Text("全部记录").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    
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
