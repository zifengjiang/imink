import SwiftUI
import SplatDatabase

struct BadgeSelectorView: View {
    @ObservedObject var viewModel: NameplateEditorViewModel
    let selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var badgeHierarchy: [BadgeNode] = []
    
    /// 依据当前徽章列表重建层级结构。
    func buildBadgeHierarchy() {
        badgeHierarchy = BadgeHierarchy.build(from: viewModel.availableBadges)
    }

    var filteredBadges: [ImageMap] {
        if searchText.isEmpty {
            return viewModel.availableBadges
        } else {
            return viewModel.availableBadges.filter { badge in
                badge.name.localizedCaseInsensitiveContains(searchText) ||
                badge.nameId.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var showHierarchy: Bool {
        return searchText.isEmpty
    }
    
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索栏
                SearchBar(text: $searchText)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            // 移除徽章选项
                            Button {
                                viewModel.setBadge(at: selectedIndex, badge: nil)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.system(size: 16))
                                        }
                                    
                                    Text("移除徽章")
                                        .font(.body)
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            
                            if showHierarchy {
                                // 层级展示
                                ForEach(badgeHierarchy) { node in
                                    BadgeNodeView(
                                        node: node,
                                        selectedIndex: selectedIndex,
                                        viewModel: viewModel,
                                        dismiss: dismiss
                                    )
                                }
                                .padding(.horizontal)
                            } else {
                                // 搜索结果的网格展示
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 15) {
                                    ForEach(filteredBadges, id: \.nameId) { badge in
                                        Button {
                                            viewModel.setBadge(at: selectedIndex, badge: badge.name)
                                            dismiss()
                                        } label: {
                                            VStack(spacing: 8) {
                                                Image(badge.name)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 60, height: 60)
                                                    .background(Color(.systemGray6))
                                                    .cornerRadius(8)
                                                    .overlay {
                                                        // 如果当前已选中，显示选中状态
                                                        if viewModel.selectedBadges[selectedIndex] == badge.name {
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .stroke(Color.accentColor, lineWidth: 3)
                                                        }
                                                    }
                                                
                                                Text(badge.name.replacingOccurrences(of: "Badge_", with: ""))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择徽章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                buildBadgeHierarchy()
            }
            .onChange(of: viewModel.availableBadges) { _ in
                buildBadgeHierarchy()
            }
        }
    }
}

#Preview {
    BadgeSelectorView(viewModel: NameplateEditorViewModel(), selectedIndex: 0)
}
