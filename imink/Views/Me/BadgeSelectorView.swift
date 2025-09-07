import SwiftUI
import SplatDatabase

struct BadgeSelectorView: View {
    @ObservedObject var viewModel: NameplateEditorViewModel
    let selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
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
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 15) {
                            // 移除徽章选项
                            Button {
                                viewModel.setBadge(at: selectedIndex, badge: nil)
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.system(size: 24))
                                        }
                                    
                                    Text("移除")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 徽章选项
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
            .navigationTitle("选择徽章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索徽章...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    BadgeSelectorView(viewModel: NameplateEditorViewModel(), selectedIndex: 0)
}
