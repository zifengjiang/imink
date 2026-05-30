import SwiftUI

struct AccountReviewView: View {
    @StateObject var viewModel = AccountReviewViewModel()
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading) {
            if let historyRecord = viewModel.historyRecord {
                accountContent(historyRecord)
            } else if appState.isLogin {
                AccountReviewSkeleton()
            } else {
                loggedOutContent
            }
        }
        .padding(.all, 10)
        .background(.listItemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: appState.isLogin) {
            guard appState.isLogin, viewModel.historyRecord == nil else { return }
            await viewModel.loadHistoryRecord()
        }
        .onTapGesture {
            guard appState.isLogin else { return }
            Task {
                await viewModel.loadHistoryRecord()
            }
        }
    }

    private func accountContent(_ historyRecord: HistoryRecord) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 6) {
                avatar(for: historyRecord)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .lastTextBaseline) {
                        Text(historyRecord.account.name ?? "----")
                            .font(.splatoonFont(size: 20))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .foregroundStyle(.appLabel)
                            .frame(width: 50, height: 20)

                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text("★")
                                .font(.splatoonFont(size: 15))
                                .foregroundStyle(.spYellow)
                            Text("\(historyRecord.rank)")
                                .font(.splatoonFont(size: 13))
                        }
                        HStack(alignment: .bottom, spacing: 0) {
                            Text("\(historyRecord.udemae ?? "-")")
                                .font(.splatoonFont(size: 13))
                            Text("\(historyRecord.udemaeMax ?? "-")")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    NameplateView(nameplate: historyRecord.nameplate)
                        .frame(height: 40)
                }
            }

            CarouselView(activeIndex: .constant(1), autoScrollDuration: 5) {
                MedalRow(icon: Image(.anarchy), description: "蛮颓开放", history: historyRecord.bankaraMatchOpenPlayHistory)
                    .tag(0)
                MedalRow(icon: Image(.event), description: "活动比赛", history: historyRecord.leagueMatchPlayHistory)
                    .tag(1)
                MedalRow(icon: Image(.coopTeamContest), description: "打工竞赛", history: historyRecord.leagueMatchPlayHistory)
                    .tag(2)
            }
            .frame(height: 55)
        }
    }

    @ViewBuilder
    private func avatar(for historyRecord: HistoryRecord) -> some View {
        if let data = historyRecord.account.avatar, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .frame(width: 60, height: 60)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        } else {
            Capsule()
                .foregroundColor(.secondary)
                .frame(width: 60, height: 60)
        }
    }

    private var loggedOutContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 60, height: 60)
                .background(Color(.systemGray5), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("尚未登录")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.appLabel)

                Text("登录后同步 SplatNet 3 账号资料与记录。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 96)
    }

    private struct AccountReviewSkeleton: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 9) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(.systemGray5))
                            .frame(width: 128, height: 18)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(.systemGray5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                    }
                }

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(height: 44)
            }
            .frame(maxWidth: .infinity, minHeight: 129, alignment: .leading)
            .swShimmer()
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
