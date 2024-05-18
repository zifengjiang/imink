import SwiftUI

struct MePage: View {
    
    @State var showSetting:Bool = false

    var body: some View {
        NavigationStack{
            List {
                Text("hello")
            }
            .navigationTitle("tab_me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSetting = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }

        }
        .sheet(isPresented: $showSetting) {
            SettingPage(showSettings: $showSetting)
        }


    }
}

#Preview {
    MePage()
}
