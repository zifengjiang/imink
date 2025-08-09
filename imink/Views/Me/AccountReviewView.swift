import SwiftUI

struct AccountReviewView: View {
    @StateObject var viewModel = AccountReviewViewModel()
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 6) {
                if let historyRecord = viewModel.historyRecord{
                    if let data = historyRecord.account.avatar, let uiImage = UIImage(data: data){
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    } else{
                        Capsule()
                            .foregroundColor(.secondary)
                            .frame(width: 60, height: 60)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .lastTextBaseline) {
                            Text(historyRecord.account.name ?? "----")
                                .font(.splatoonFont(size: 20))
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                                .foregroundStyle(.appLabel)
                                .frame(width: 50, height: 20)

                            HStack(alignment: .lastTextBaseline,spacing: 0) {
                                Text("★")
                                    .font(.splatoonFont(size: 15))
                                    .foregroundStyle(.spYellow)
                                Text("\(viewModel.historyRecord?.rank ?? 0)")
                                    .font(.splatoonFont(size: 13))
                            }
                            HStack(alignment: .bottom, spacing: 0) {
                                Text("\(viewModel.historyRecord?.udemae ?? "-")")
                                    .font(.splatoonFont(size: 13))
                                Text("\(viewModel.historyRecord?.udemaeMax ?? "-")")
                                    .font(.splatoonFont(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        NameplateView(nameplate: historyRecord.nameplate)
                            .frame(height: 40)
                    }
                }
            }

            CarouselView(activeIndex: .constant(1), autoScrollDuration: 5) {
                MedalRow(icon: Image(.anarchy), description: "蛮颓开放", history: viewModel.historyRecord?.bankaraMatchOpenPlayHistory)
                    .tag(0)
                MedalRow(icon: Image(.event), description: "活动比赛", history: viewModel.historyRecord?.leagueMatchPlayHistory)
                    .tag(1)
                MedalRow(icon: Image(.coopTeamContest), description: "打工竞赛", history: viewModel.historyRecord?.leagueMatchPlayHistory)
                    .tag(2)
            }
            .frame(height: 55)
        }
        .padding(.all, 10)
        .background(.listItemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            Task{
                await viewModel.loadHistoryRecord()
            }
        }
    }

    struct MedalRow:View {
        let icon:Image
        let description:String
        let history:PlayHistoryTrophyRecord?
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .frame(maxWidth: .infinity)
                    .frame(height: 1.0 / UIScreen.main.scale)
                    .foregroundColor(Color(.separator))
                    .padding(.leading, 62)
                    .padding(.bottom, 12)

                HStack(alignment: .top) {
                    HStack {
                        Spacer()
                        VStack {
                            icon
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32)
                            Text(description)
                                .font(.splatoonFont(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .frame(width: 72)

                    VStack(alignment: .leading, spacing: 7) {
                        MedalView(history: history ?? PlayHistoryTrophyRecord.defaultRecord, icon: Image(.event))

                        HStack(spacing: 5) {
                            Text("参加次数")
                                .font(.system(size: 10))
                                .foregroundColor(Color(.secondaryLabel))

                            Text("\(history?.attend ?? 0)")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundColor(.appLabel)
                        }
                    }
                }
            }
            .padding(0)
        }
    }

    struct MedalView:View {
        let history:PlayHistoryTrophyRecord
        let icon:Image
        var body: some View {
            VStack(alignment: .trailing) {
                HStack(alignment: .bottom) {
                        //          icon
                        //            .resizable()
                        //            .scaledToFit()
                        //            .frame(width:20, height: 20)
                    HStack(alignment:.bottom, spacing:0){
                        Image(.trophyGold)
                            .resizable()
                            .scaledToFit()
                            .frame(width:25, height: 25)
                        Text("x\(history.gold)")
                            .font(.splatoonFont(size: 12))
                    }
                    HStack(alignment:.bottom, spacing:0){
                        Image(.trophySilver)
                            .resizable()
                            .scaledToFit()
                            .frame(width:25, height: 25)

                        Text("x\(history.silver)")
                            .font(.splatoonFont(size: 12))
                    }
                    HStack(alignment:.bottom, spacing:0){
                        Image(.trophyBronze)
                            .resizable()
                            .scaledToFit()
                            .frame(width:25, height: 25)

                        Text("x\(history.bronze)")
                            .font(.splatoonFont(size: 12))
                    }
                }
            }

        }
    }
}



class AccountReviewViewModel:ObservableObject{
    @Published var historyRecord:HistoryRecord?
    private let inkNet = SN3Client.shared

    init(){
        if let data = AppUserDefaults.shared.historyRecord?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(HistoryRecord.self, from: data){
            self.historyRecord = decoded
        }
    }


    func loadHistoryRecord() async {
        let historyRecord:HistoryRecord?  = await inkNet.fetchRecord(.historyRecord)
        if let data = try? JSONEncoder().encode(historyRecord),
           let jsonString = String(data: data, encoding: .utf8) {
            AppUserDefaults.shared.historyRecord = jsonString
        }
        DispatchQueue.main.async {
            self.historyRecord = historyRecord
        }
    }
}

#Preview {
    AccountReviewView()
}
