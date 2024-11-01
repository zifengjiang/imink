import SwiftUI

struct MePage: View {
    
    @State var showSetting:Bool = false

    var body: some View {
        NavigationStack{
            List {
                AccountReviewView()
                Section{
                    NavigationLink("打工记录", destination: CoopRecordView())
                    NavigationLink("祭典记录", destination: CoopRecordView())
                    NavigationLink("场地记录", destination: StageRecordView())
                    NavigationLink("武器记录", destination: CoopRecordView())
                }
            }
            .navigationTitle("tab_me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSetting = true
                    }) {
                        Image("setting")
                            .resizable()
                            .scaledToFit()
                            .overlay(Color(.accent))
                            .mask{
                                Image("setting")
                                    .resizable()
                                    .scaledToFit()
                            }
                            .frame(width: 20*1.2)
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
