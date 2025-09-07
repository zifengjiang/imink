import SwiftUI

struct NameplateEditorView: View {
    @StateObject private var viewModel = NameplateEditorViewModel()
    @State private var showingBadgeSelector = false
    @State private var showingBackgroundSelector = false
    @State private var selectedBadgeIndex = 0
    @State private var showingColorPicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {                
                // 预览区域
                VStack(spacing: 15) {
                    Text("预览")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    EditableNameplateView(
                        viewModel: viewModel,
                        showingBadgeSelector: $showingBadgeSelector,
                        showingBackgroundSelector: $showingBackgroundSelector,
                        selectedBadgeIndex: $selectedBadgeIndex
                    )
                    .frame(height: 120)
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 编辑选项
                VStack(spacing: 20) {
                    // 文本编辑
                    VStack(alignment: .leading, spacing: 12) {
                        Text("文本设置")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("玩家名称:")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            TextField("输入玩家名称", text: $viewModel.customName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    viewModel.saveCurrentSettings()
                                }
                                .onChange(of: viewModel.customName) { _, _ in
                                    // 延迟保存，避免频繁写入
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        viewModel.saveCurrentSettings()
                                    }
                                }
                        }
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("称号:")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            TextField("输入称号", text: $viewModel.customByname)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    viewModel.saveCurrentSettings()
                                }
                                .onChange(of: viewModel.customByname) { _, _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        viewModel.saveCurrentSettings()
                                    }
                                }
                        }
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("玩家ID:")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            TextField("输入玩家ID", text: $viewModel.customNameId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .onSubmit {
                                    viewModel.saveCurrentSettings()
                                }
                                .onChange(of: viewModel.customNameId) { _, _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        viewModel.saveCurrentSettings()
                                    }
                                }
                        }
                    }
                    
                    Divider()
                    
                    // 颜色选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("字体颜色")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                            ForEach(viewModel.presetColors.indices, id: \.self) { index in
                                let color = viewModel.presetColors[index]
                                Button {
                                    viewModel.setTextColor(color)
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            if viewModel.selectedTextColor == color {
                                                Circle()
                                                    .stroke(Color.accentColor, lineWidth: 3)
                                            }
                                        }
                                        .overlay {
                                            // 为白色和黑色添加边框以便区分
                                            if color == .white || color == .black {
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            }
                                        }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Button {
                            showingColorPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "eyedropper")
                                Text("自定义颜色")
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    Divider()
                    
                    // 快捷操作
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷操作")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            HStack(spacing: 15) {
                                Button {
                                    showingBackgroundSelector = true
                                } label: {
                                    Label("更换背景", systemImage: "photo")
                                }
                                .buttonStyle(.bordered)
                                
                                Button {
                                    viewModel.resetToDefault()
                                } label: {
                                    Label("重置", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            // 保存到相册按钮
                            Button {
                                viewModel.saveNameplateToPhotos()
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("保存到相册")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .navigationTitle("铭牌编辑器")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingBadgeSelector) {
            BadgeSelectorView(viewModel: viewModel, selectedIndex: selectedBadgeIndex)
        }
        .sheet(isPresented: $showingBackgroundSelector) {
            BackgroundSelectorView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPicker("选择字体颜色", selection: $viewModel.selectedTextColor)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    NavigationView {
        NameplateEditorView()
    }
}
