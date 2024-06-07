import SwiftUI
import SplatDatabase

struct SettingPage: View {
    @Binding var showSettings: Bool
    
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var coopListViewModel: CoopListViewModel
    @State var showFilePicker = false
    @State private var isActivityPresented = false
    @State private var item: Any = URL(fileURLWithPath: SplatDatabase.shared.dbQueue.path)
    var body: some View {
        NavigationStack{
            List{
                Button {
                    AppUserDefaults.shared.sessionToken = nil
//                    mainViewModel.isLogin = false
                } label: {
                    Text("setting_button_logout")
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
                        //TODO: export user data
                    } label: {
                        Text("setting_button_export_user_data")
                    }

                    Button{
                        Task{
                            showSettings = false
                            await fetchHistorySchedules()
                        }
                    } label: {
                        Text("获取历史日程")
                    }

                    Button {
                        self.isActivityPresented = true
                    } label: {
                        Text("导出数据库")
                    }
                    .background(ActivityView(isPresented: $isActivityPresented, item: $item))

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
