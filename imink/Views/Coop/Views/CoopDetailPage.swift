import SwiftUI
import Photos

/// 打工详情页（单页）。
///
/// 先前这里用 page 风格 `TabView` 支持左右滑动切换记录，但该容器会把子页
/// 重新压回安全区，导致内容无法伸到导航栏/标签栏之下（顶部被挡、留白异常），
/// 且在 iOS 27 上行为与 iOS 26 不一致。滑动切换的收益远小于这些代价，故改为
/// 与对战详情一致的单页结构。
struct CoopDetailPage: View {
    let rowId: String
    @ObservedObject var viewModel: CoopListViewModel
    @Binding var navigationPath: NavigationPath

    private var row: CoopListRowModel? {
        viewModel.rows.first { $0.id == rowId }
    }

    var body: some View {
        Group {
            if let detail = row?.detail {
                CoopDetailView(id: detail.id, navigationPath: $navigationPath)
            } else if let card = row?.card {
                CoopShiftDetailView(id: card.groupId, navigationPath: $navigationPath)
            } else {
                Color.clear
            }
        }
        .toolbar {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    Task { await viewModel.toggleFavorite(for: rowId) }
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
                        .frame(width: 20 * 1.2)
                        .offset(y: -4)
                }
            }
        }
        .onAppear {
            viewModel.loadCurrentCoopFavoriteStatus(for: rowId)
        }
    }

    // MARK: - 保存为图片

    private func saveImageToPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    performSaveImage()
                case .denied, .restricted:
                    Toast.failure("没有相册权限", subtitle: "请在设置中允许访问相册")
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func performSaveImage() {
        guard let coop = row?.detail else { return }

        let image = CoopDetailView(id: coop.id, navigationPath: .constant(NavigationPath()))
            .asUIImage(size: CGSize(width: 400, height: coop.height))

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            Task { @MainActor in
                if success {
                    Toast.success("保存成功", subtitle: "图片已保存到相册")
                } else if let error {
                    Toast.failure("保存失败", subtitle: error.localizedDescription)
                }
                // 清理视图模型
                AppState.shared.viewModelDict[coop.id] = nil
            }
        }
    }
}
