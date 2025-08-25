import SwiftUI

struct MePage: View {
    
    var body: some View {
        NavigationStack{
            List {
                AccountReviewView()
                Section{
                    NavigationLink("打工记录", destination: CoopRecordView())
                    NavigationLink("祭典记录", destination: CoopRecordView())
                    NavigationLink("场地记录", destination: StageRecordView())
                    NavigationLink("武器记录", destination: WeaponRecordView())
                }
                
                Section("数据管理"){
                    NavigationLink("回收站", destination: TrashView())
                        .foregroundColor(.primary)
                }
            }
            .navigationTitle("tab_me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingPage()) {
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
                    .onTapGesture {
                        Haptics.generateIfEnabled(.light)
                    }
                }
            }
        }
    }
}

#Preview {
    MePage()
}
