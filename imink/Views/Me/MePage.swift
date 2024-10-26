import SwiftUI
import SplatNet3API

struct MePage: View {
    
    @State var showSetting:Bool = false

    var body: some View {
        NavigationStack{
            List {
                Section{
                    NavigationLink("鲑鱼跑记录", destination: SalmonRunStatsPage())
                }
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
        .refreshable{
            await SN3Client.shared.fetchHistoryRecord()
        }


    }
}

#Preview {
    MePage()
}
