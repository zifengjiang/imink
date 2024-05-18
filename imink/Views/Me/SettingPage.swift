import SwiftUI
import SplatDatabase

struct SettingPage: View {
    @Binding var showSettings: Bool

    @State var showFilePicker = false
    var body: some View {
        NavigationStack{
            List{
                Section(header: Text("setting_section_user_data")){
                    Button {
                        showFilePicker = true
                    } label: {
                        Text("setting_button_import_user_data")
                    }
                    .sheet(isPresented: $showFilePicker) {
                        FilePickerView(fileType: .data) { url in
                            do{
                                try SplatDatabase.shared.importFromConchBay(dbPath: url.path()) { progress in
                                    print(progress)
                                }
                            }catch{
                                print(error)
                            }
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
