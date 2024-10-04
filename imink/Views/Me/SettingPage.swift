import SwiftUI
import SplatDatabase
import IndicatorsKit

struct SettingPage: View {
    @Binding var showSettings: Bool
    
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var coopListViewModel: CoopListViewModel
    @State var showFilePicker = false
    @State private var isActivityPresented = false
    @State var showLogoutAlert = false
    @State var showCopySessionIdAlert = false
    @State private var item: Any = URL(fileURLWithPath: SplatDatabase.shared.dbQueue.path)
    var body: some View {
        NavigationStack{
            List{
                Section(header: Text("账户")){
                    Button(action: {
                        showCopySessionIdAlert = true

                    }) {
                        Text("复制会话令牌")
                    }
                    .alert(isPresented: $showCopySessionIdAlert) {
                        Alert(
                            title: Text("复制会话令牌"),
                            message: Text("复制会话令牌的不当传播会导致隐私泄露, 你确定要复制会话令牌吗?"),
                            primaryButton: .destructive(Text("确认")) {
                                UIPasteboard.general.string = AppUserDefaults.shared.sessionToken
                            },
                            secondaryButton: .cancel()
                        )
                    }

                    Button {
                        showLogoutAlert = true
                    } label: {
                        Text("setting_button_logout")
                    }
                    .alert(isPresented: $showLogoutAlert) {
                        Alert(
                            title: Text("退出登录"),
                            message: Text("你确定要退出登录吗？"),
                            primaryButton: .destructive(Text("确认")) {
                                    // 当用户点击“Logout”按钮时，执行注销操作
                                AppUserDefaults.shared.sessionToken = nil
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }

                Section(header: Text("setting_section_user_data")){
                    Button {
                        showFilePicker = true
                    } label: {
                        Text("setting_button_import_user_data")
                    }
                    .sheet(isPresented: $showFilePicker) {
                        FilePickerView(fileType: .zip) { url in
                            showSettings = false
                            coopListViewModel.cancel()
                            DataBackup.import(url: url)
                        }
                    }

                    Button {
                        self.isActivityPresented = true
                    } label: {
                        Text("setting_button_export_user_data")
                    }
                    .background(ActivityView(isPresented: $isActivityPresented, item: $item))

                }

                Section(header: Text("关于Imink")){
                    Button{
                        Task{
                            showSettings = false
                            await fetchHistorySchedules()
                        }
                    } label: {
                        Text("获取历史日程")
                    }

                    Button {

                    } label: {
                        HStack{
                            Text("NSO版本")
                            Spacer()
                            Text("\(AppUserDefaults.shared.NSOVersion)").foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .navigationTitle("setting_page_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showSettings = false
                    }) {
                        Text("setting_page_done")
                            .foregroundStyle(.accent)
                            .frame(height: 40)
                    }
                }
            }
        }
    }

    func exportDatabase(){
        let fileManager = FileManager.default
        let databasePath = URL(fileURLWithPath: SplatDatabase.shared.dbQueue.path)

            // Copy to temporary directory
        guard let tempDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let tempFilePath = tempDirectory.appendingPathComponent("db.sqlite")

        do {
            if fileManager.fileExists(atPath: tempFilePath.path) {
                try fileManager.removeItem(at: tempFilePath)
            }
            try fileManager.copyItem(at: databasePath, to: tempFilePath)

            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    if rootViewController.presentedViewController == nil {
                        let documentPicker = UIDocumentPickerViewController(forExporting: [tempFilePath])
                        rootViewController.present(documentPicker, animated: true, completion: nil)
                    } else {
                        rootViewController.dismiss(animated: true) {
                            let documentPicker = UIDocumentPickerViewController(forExporting: [tempFilePath])
                            rootViewController.present(documentPicker, animated: true, completion: nil)
                        }
                    }
                }
            }
        } catch {
            print("Failed to copy file to temporary directory: \(error)")
        }
    }
}




#Preview {
    SettingPage(showSettings: .constant(false))
}
