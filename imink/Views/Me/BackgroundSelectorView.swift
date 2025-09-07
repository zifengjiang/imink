import SwiftUI
import SplatDatabase

struct BackgroundSelectorView: View {
    @ObservedObject var viewModel: NameplateEditorViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
    var filteredBackgrounds: [ImageMap] {
        if searchText.isEmpty {
            return viewModel.availableBackgrounds
        } else {
            return viewModel.availableBackgrounds.filter { background in
                background.name.localizedCaseInsensitiveContains(searchText) ||
                background.nameId.localizedCaseInsensitiveContains(searchText)
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
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 15) {
                            ForEach(filteredBackgrounds, id: \.nameId) { background in
                                Button {
                                    viewModel.setBackground(background.name)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        // 背景预览
                                        Image(background.name)
                                            .resizable()
                                            .aspectRatio(3.5, contentMode: .fill)
                                            .frame(width: 160)
                                            .clipped()
                                            .cornerRadius(3)
                                            .overlay {
                                                // 如果当前已选中，显示选中状态
                                                if viewModel.selectedBackground == background.name {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.accentColor, lineWidth: 3)
                                                }
                                            }
//                                            .overlay(alignment: .center) {
//                                                // 在背景上显示示例文字
//                                                Text("示例")
//                                                    .font(.splatoonFont1(size: 16))
//                                                    .foregroundColor(viewModel.selectedTextColor)
//                                            }
                                        
                                        Text(background.name.replacingOccurrences(of: "Npl_", with: ""))
                                            .font(.caption)
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
            .navigationTitle("选择背景")
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

#Preview {
    BackgroundSelectorView(viewModel: NameplateEditorViewModel())
}
