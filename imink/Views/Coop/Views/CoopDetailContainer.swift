import SwiftUI
import Photos

struct CoopDetailContainer: View {
    let rows: [CoopListRowModel]
    @Binding var selectedRow: String?
    @ObservedObject var viewModel: CoopListViewModel
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        TabView(selection: $selectedRow) {
            ForEach(rows, id: \.id) { row in
                CoopListDetailView(
                    isCoop: row.isCoop, 
                    coopId: row.coop?.id, 
                    shiftId: row.card?.groupId,
                    navigationPath: $navigationPath
                )
                .scrollIndicators(.hidden)
//                .scrollClipDisabled()
                .containerRelativeFrame(.horizontal)
                .tag(row.id)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
//        .padding(.vertical,50) // leave space for toolbar
        .edgesIgnoringSafeArea(.vertical)

        .fixSafeareaBackground()
//        .onAppear {
//            if let firstRow = rows.first {
//                selectedRow = firstRow.id
//                viewModel.loadCurrentCoopFavoriteStatus(for: firstRow.id)
//            }
//        }
        .toolbar {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    moveToPreviousRow()
                    Haptics.generateIfEnabled(isFirstRow ? .error : .light)
                } label: {
                    Image("KEEP")
                        .resizable()
                        .scaledToFill()
                        .rotationEffect(.degrees(180))
                        .overlay(isFirstRow ? Color(.gray) : Color(.accent))
                        .mask {
                            Image("KEEP")
                                .resizable()
                                .scaledToFit()
                                .rotationEffect(.degrees(180))
                        }
                        .frame(width: 20*1.2, height: 10*1.2)
                }
                
                Button {
                    moveToNextRow()
                    Haptics.generateIfEnabled(.light)
                } label: {
                    Image("KEEP")
                        .resizable()
                        .scaledToFill()
                        .overlay(Color(.accent))
                        .mask {
                            Image("KEEP")
                                .resizable()
                                .scaledToFit()
                        }
                        .frame(width: 20*1.2, height: 10*1.2)
                }
                
                Button {
                    Task {
                        await viewModel.toggleFavorite(for: selectedRow)
                    }
                    Haptics.generateIfEnabled(.light)
                } label: {
                    Image(systemName: viewModel.currentCoopIsFavorite ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.currentCoopIsFavorite ? .red : .accentColor)
                        .font(.system(size: 18))
                }
                
                Button {
                    Haptics.generateIfEnabled(.medium)
                    saveImageToPhotos()
                } label: {
                    Image("share")
                        .resizable()
                        .scaledToFit()
                        .overlay(Color(.accent))
                        .mask {
                            Image("share")
                                .resizable()
                                .scaledToFit()
                        }
                        .frame(width: 20*1.2)
                        .offset(y: -4)
                }
            }
        }
    }
    
    private var isFirstRow: Bool {
        selectedRow == rows.first?.id
    }
    
    private func moveToNextRow() {
        if let index = rows.firstIndex(where: {$0.id == selectedRow}), index < rows.count - 1 {
            withAnimation {
                selectedRow = rows[index + 1].id
            }
        }
    }
    
    private func moveToPreviousRow() {
        if let index = rows.firstIndex(where: {$0.id == selectedRow}), index > 0 {
            withAnimation {
                selectedRow = rows[index - 1].id
            }
        }
    }
    
    private func saveImageToPhotos() {
        // 直接请求权限，系统会自动处理弹窗
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.performSaveImage()
                case .denied, .restricted:
                    print("照片库访问权限被拒绝")
                    // 可以在这里添加用户友好的提示
                case .notDetermined:
                    print("权限状态未确定")
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func performSaveImage() {
        guard let rowId = selectedRow,
              let coop = rows.first(where: { $0.id == rowId })?.coop else {
            return
        }
        
        @State var tempNavigationPath = NavigationPath()
        let image = CoopDetailView(id: coop.id, navigationPath: .constant(NavigationPath())).asUIImage(size: CGSize(width: 400, height: coop.height))
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 显示保存成功提示，2秒后自动关闭
                    Indicators.shared.display(.init(
                        id: UUID().uuidString,
                        icon: .systemImage("checkmark.circle.fill"),
                        title: "保存成功",
                        subtitle: "图片已保存到相册",
                        dismissType: .after(2)
                    ))
                } else if let error = error {
                    // 显示保存失败提示
                    Indicators.shared.display(.init(
                        id: UUID().uuidString,
                        icon: .systemImage("xmark.circle.fill"),
                        title: "保存失败",
                        subtitle: error.localizedDescription,
                        dismissType: .after(3),
                        style: .error
                    ))
                }
                // 清理视图模型
                AppState.shared.viewModelDict[coop.id] = nil
            }
        }
    }
}
