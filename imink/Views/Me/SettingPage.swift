import SwiftUI
import SplatDatabase

struct SettingPage: View {
    @Binding var showSettings: Bool
    
    @EnvironmentObject var mainViewModel: MainViewModel
    @State var showFilePicker = false
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
                            DataBackup.import(url: url)
                        }
                    }

                    Button {
                        //TODO: export user data
                    } label: {
                        Text("setting_button_export_user_data")
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
}

#Preview {
    SettingPage(showSettings: .constant(false))
}
