import SwiftUI
import Photos

/// 打工详情页（单页）。
///
/// 区分「单局打工详情」与「班次汇总详情」上下文：
/// 收藏（心形）与保存单局快照到相册仅在 `row?.detail != nil` 时展示，
/// 避免在班次汇总页显示上一个打工遗留的收藏态或点击无响应。
struct CoopDetailPage: View {
    let rowId: String
    @ObservedObject var viewModel: CoopListViewModel
    @Binding var navigationPath: NavigationPath

    private var row: CoopListRowModel? {
        viewModel.rows.first { $0.id == rowId }
    }

    private var isSingleCoopDetail: Bool {
        row?.detail != nil
    }

    var body: some View {
        Group {
            if let detail = row?.detail {
                CoopDetailView(id: detail.id, navigationPath: $navigationPath)
            } else if let card = row?.card {
                CoopShiftDetailView(id: card.groupId, navigationPath: $navigationPath)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(.appDisplay)
                        .foregroundStyle(.secondary)
                    Text("未找到该打工记录")
                        .font(.appHeadline)
                        .foregroundStyle(.appLabel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .fixSafeareaBackground()
            }
        }
        .toolbar {
            if isSingleCoopDetail {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(alignment: .center, spacing: 10) {
                        Button {
                            Task { await viewModel.toggleFavorite(for: rowId) }
                            Haptics.generateIfEnabled(.light)
                        } label: {
                            Image(systemName: viewModel.currentCoopIsFavorite ? "heart.fill" : "heart")
                                .foregroundColor(viewModel.currentCoopIsFavorite ? .red : .accentColor)
                                .font(.appHeadline)
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
            }
        }
        .onAppear {
            viewModel.loadCurrentCoopFavoriteStatus(for: rowId)
        }
    }

    // MARK: - 保存为图片

    private func saveImageToPhotos() {
        guard row?.detail != nil else { return }
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
                AppState.shared.viewModelDict[coop.id] = nil
            }
        }
    }
}
