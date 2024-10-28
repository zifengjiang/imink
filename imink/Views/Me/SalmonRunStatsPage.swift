import SwiftUI
import SplatNet3API

struct SalmonRunStatsPage: View {
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
                .frame(maxWidth: .infinity)
                .fixSafeareaBackground()
            } else {
                VStack(alignment: .center){
                    Spacer()
                    Image(.squidLoading)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundStyle(.gray)
                    Text("Loading...")
                        .font(.splatoonFont(size: 25))
                    Spacer()
                }

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


class SalmonRunStatsViewModel:ObservableObject{
    @Published var coopRecord:CoopRecord?


    init() {
        Task{@MainActor in
            await loadCoopRecord()
        }
    }

    @MainActor
    func loadCoopRecord() async {
        self.coopRecord = await SN3Client.shared.fetchCoopRecord()
    }
}


struct DividerViewBuilder<Content: View, Item>: View {
    var items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            content(item)
            if index < items.count - 1 {
                Divider()
            }
        }
    }
}
