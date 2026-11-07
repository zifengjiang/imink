import SwiftUI

struct CoopRecordView: View {
    @StateObject var model = SalmonRunStatsViewModel()
    var body: some View {
        VStack {
            if let coopRecord = model.coopRecord {
                ScrollView{
                    HStack {
                        Spacer()
                        VStack(spacing:20){

                            VStack(spacing: 5){

                                HStack {
                                    Image(.salmonRun)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                    Text("最高分数")
                                        .font(.splatoonFont(size: 25))
                                        .foregroundStyle(.salmonRunTheme)
                                }

                                StageRecord(stageHighestRecords: coopRecord.stageHighestRecords)
                                    .padding(.leading, 0)
                                    .padding(.vertical,0)
                                    .textureBackground(texture: .streak, radius: 18)
                            }

                            VStack{
                                HStack {
                                    Image(.salmonRun)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                    Text("击倒数量")
                                        .font(.splatoonFont(size: 25))
                                        .foregroundStyle(.salmonRunTheme)
                                }
                                HStack(spacing:20){
                                    ForEach(coopRecord.defeatBossRecords, id:\.enemy){boss in
                                        VStack{
                                            Image(boss.enemyImage ?? "dummyImage")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 50, height: 50)
                                            Text("\(boss.defeatCount)")
                                                .font(.splatoonFont(size: 15))
                                        }
                                    }
                                }

                                EnemyView(defeatEnemyRecords: coopRecord.defeatEnemyRecords)
                                    .padding(.all)
                                    .background(.listItemBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }



                        }
                        Spacer()
                    }
                    .padding(.horizontal,8)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity)
                .fixSafeareaBackground()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task {
                                await model.refreshRemote()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            } else {
                LoadingView(size: 100)
            }
        }
    }


    struct EnemyView:View {
        let defeatEnemyRecords:[DefeatEnemyRecord]
        var body: some View {
            VStack {
                DividerViewBuilder(items: defeatEnemyRecords){ enemy in
                    HStack{
                        Image(enemy.enemyImage ?? "dummyImage")
                            .resizable()
                            .scaledToFit()
                            .frame(width:35, height: 35)
                        Text("\(enemy.enemy.localizedFromSplatNet)")
                            .font(.splatoonFont(size: 15))
                        Spacer()
                        Text("\(enemy.defeatCount)")
                            .font(.splatoonFont(size: 15))
                    }
                }
            }
        }
    }

    struct StageRecord:View {
        let stageHighestRecords:[StageHighestRecord]
        var body: some View {
            VStack{
                DividerViewBuilder(items: stageHighestRecords) { stageRecord in
                    HStack(spacing:0){
                        Spacer()
                        VStack(alignment:.leading,spacing: 10){
                            HStack {
                                Text("\(stageRecord.coopStage)".localizedFromSplatNet)
                                    .font(.splatoonFont(size: 15))
                                    //                                    .scaledLimitedLine()
                                Spacer()
                            }

                            HStack(spacing:5){
                                Text("最高评价")
                                    .foregroundStyle(.secondary)
                                Text("\(stageRecord.grade)".localizedFromSplatNet)
                                Text("\(stageRecord.gradePoint)")
                            }
                            .font(.splatoonFont(size: 15))
                        }
                        Image(stageRecord.coopStageImage ?? "dummyStage")
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10,style: .continuous))
                            .frame(width:150, height: 80)




                    }
                }
            }
        }
    }
}


@MainActor
final class SalmonRunStatsViewModel: ObservableObject, CachedRecordViewModel {
    typealias Record = CoopRecord

    @Published var coopRecord: CoopRecord?

    var value: CoopRecord? {
        get { coopRecord }
        set { coopRecord = newValue }
    }

    func readCache() -> CoopRecord? {
        AppUserDefaults.shared.coopRecordCache
    }

    func writeCache(_ record: CoopRecord) {
        AppUserDefaults.shared.coopRecordCache = record
    }

    func fetchRemote() async -> CoopRecord? {
        await SN3Client.shared.fetchRecord(.coopRecord)
    }

    init() {
        Task { await loadCachedThenRemote() }
    }
}


