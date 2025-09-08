import SwiftUI
import SplatDatabase
import GRDB
import Photos

extension ImageMap: @retroactive Equatable{
    public static func == (lhs: ImageMap, rhs: ImageMap) -> Bool {
        lhs.name == rhs.name && lhs.nameId == rhs.nameId && lhs.hash == rhs.hash
    }
    
    
}

@MainActor
class NameplateEditorViewModel: ObservableObject {
    @Published var customName: String = "自定义玩家"
    @Published var customByname: String = "自定义称号"
    @Published var customNameId: String = "0000"
    @Published var selectedBackground: String = "Npl_Tutorial00"
    @Published var selectedBadges: [String?] = [nil, nil, nil] // 最多3个徽章
    @Published var selectedTextColor: Color = .white
    
    @Published var availableBackgrounds: [ImageMap] = []
    @Published var availableBadges: [ImageMap] = []
    @Published var isLoading: Bool = false
    
    init() {
        loadSavedSettings()
        Task {
            await loadAssets()
        }
    }
    
    func loadAssets() async {
        isLoading = true
        
        do {
            // 加载所有背景（Npl_开头）
            let backgrounds = try await SplatDatabase.shared.dbQueue.read { db in
                try ImageMap.fetchAll(db, sql: "SELECT * FROM imageMap WHERE name LIKE 'Npl_%' ORDER BY name")
            }
            
            // 加载所有徽章（Badge_开头）
            let badges = try await SplatDatabase.shared.dbQueue.read { db in
                try ImageMap.fetchAll(db, sql: "SELECT * FROM imageMap WHERE name LIKE 'Badge_%' ORDER BY name")
            }
            
            await MainActor.run {
                self.availableBackgrounds = backgrounds
                self.availableBadges = badges
                
                
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("Error loading assets: \(error)")
        }
    }
    
    func setBadge(at index: Int, badge: String?) {
        guard index >= 0 && index < selectedBadges.count else { return }
        selectedBadges[index] = badge
        saveSettings()
    }
    
    func removeBadge(at index: Int) {
        guard index >= 0 && index < selectedBadges.count else { return }
        selectedBadges[index] = nil
        saveSettings()
    }
    
    func setBackground(_ background: String) {
        selectedBackground = background
        saveSettings()
    }
    
    func setTextColor(_ color: Color) {
        selectedTextColor = color
        saveSettings()
    }
    
    // 预设颜色选项
    var presetColors: [Color] {
        [
            .white, .black, .red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan
        ]
    }
    
    // 重置为默认设置
    func resetToDefault() {
        customName = "自定义玩家"
        customByname = "自定义称号"
        customNameId = "0000"
        selectedBadges = [nil, nil, nil]
        selectedTextColor = .white
        if let firstBackground = availableBackgrounds.first {
            selectedBackground = firstBackground.name
        }
    }
    
    // 保存铭牌到相册
    func saveNameplateToPhotos() {
        // 检查照片库访问权限
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.performSaveNameplate()
                case .denied, .restricted:
                    self.showSaveError("照片库访问权限被拒绝")
                case .notDetermined:
                    print("权限状态未确定")
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func performSaveNameplate() {
        // 创建一个固定尺寸的铭牌视图，强制填充整个区域
        let saveView = createSaveableNameplateView()
            .frame(width: 700, height: 200)
            .clipped()
            .ignoresSafeArea()
        
        // 设置合适的尺寸 (铭牌比例 3.5:1)
        let size = CGSize(width: 700, height: 200)
        let image = renderViewAsImage(view: saveView, size: size)
        
        // 保存到相册
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.showSaveSuccess()
                } else if let error = error {
                    self.showSaveError(error.localizedDescription)
                }
            }
        }
    }
    
    private func showSaveSuccess() {
        Indicators.shared.display(.init(
            id: UUID().uuidString,
            icon: .systemImage("checkmark.circle.fill"),
            title: "保存成功",
            subtitle: "铭牌已保存到相册",
            dismissType: .after(2)
        ))
    }
    
    private func showSaveError(_ message: String) {
        Indicators.shared.display(.init(
            id: UUID().uuidString,
            icon: .systemImage("xmark.circle.fill"),
            title: "保存失败",
            subtitle: message,
            dismissType: .after(3),
            style: .error
        ))
    }
    
    // 创建用于保存的铭牌视图（不使用 GeometryReader）
    private func createSaveableNameplateView() -> some View {
        let width: CGFloat = 700
        let height: CGFloat = 200
        
        return ZStack(alignment: .topLeading) {
            // 背景图片
            Image(selectedBackground ?? "Npl_Catalog_Season01_Lv01")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .cornerRadius(width * 0.02)
            
            // 称号文本
            VStack(alignment: .leading) {
                Text(customByname)
                    .font(.splatoonFont(size: width * 12/284))
                    .foregroundColor(selectedTextColor)
                    .padding(.top, width * 5/284)
                    .padding(.leading, width * 10/284)
                Spacer()
            }

            // 玩家名称 - 居中
            Text(customName)
                .font(.splatoonFont1(size: width * 26/284))
                .foregroundColor(selectedTextColor)
                .position(x: width / 2, y: height / 2)

            // 徽章区域
            VStack {
                Spacer()
                HStack(spacing: width * 2/284) {
                    Spacer()
                    
                    ForEach(0..<3, id: \.self) { index in
                        if index < self.selectedBadges.count, let badge = self.selectedBadges[index] {
                            Image(badge)
                                .resizable()
                                .scaledToFit()
                                .frame(width: height * 0.345, height: height * 0.345)
                                .padding([.trailing,.bottom], 1/284)
                        } else {
                            Color.clear
                                .frame(width: height * 0.345, height: height * 0.345)
                                .padding([.trailing,.bottom], 1/284)
                        }
                    }
                }
            }

            // 玩家ID
            VStack {
                Spacer()
                HStack {
                    Text("#\(customNameId)")
                        .font(.splatoonFont(size: width * 10/284))
                        .foregroundColor(selectedTextColor)
                        .padding(.leading, width * 10/284)
                        .padding(.bottom, width * 5/284)

                    Spacer()
                }
            }
        }
        .frame(width: width, height: height)
    }
    
    // 自定义渲染方法，确保视图正确填充
    private func renderViewAsImage<V: View>(view: V, size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: view)
        
        // 强制设置视图大小和位置
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = UIColor.clear
        
        // 强制布局更新
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = false // 支持透明背景
        
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        
        return renderer.image { context in
            controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
    
    // MARK: - 持久化方法
    
    private func loadSavedSettings() {
        let settings = AppUserDefaults.shared.nameplateSettings
        print(settings.selectedBackground)

        customName = settings.customName
        customByname = settings.customByname
        customNameId = settings.customNameId
        selectedBackground = settings.selectedBackground
        selectedBadges = settings.selectedBadges
        selectedTextColor = settings.selectedTextColorComponents.toColor()
    }
    
    private func saveSettings() {
        let settings = NameplateSettings(
            customName: customName,
            customByname: customByname,
            customNameId: customNameId,
            selectedBackground: selectedBackground,
            selectedBadges: selectedBadges,
            selectedTextColorComponents: ColorComponents(from: selectedTextColor)
        )
        print(settings.selectedBackground)

        AppUserDefaults.shared.nameplateSettings = settings
    }
    
    // 手动保存设置（用于文本输入等场景）
    func saveCurrentSettings() {
        saveSettings()
    }
}
