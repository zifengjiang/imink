import SwiftUI
import SplatDatabase

struct CoopListDetailItemView: View {
    
    var coop: CoopListRowInfo
    @State private var showDeleteAlert = false
    @State private var isFavorite: Bool = false
    @State private var isDeleted: Bool = false

    var dangerRateText:String{
        let dangerRate = coop.dangerRate
        if dangerRate >= 3.33{
            return "MAX!!"
        }
        return "\(Int(dangerRate*100))%"
    }

    var clear:Bool {
        coop.resultWave == coop.rule.waveCount
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if let gradeName = coop.gradeName, let gradePoint = coop.gradePoint {
                    Text(gradeName.localizedFromSplatNet)
                        .font(.splatoonFont(size: 12))
                    Text("\(gradePoint)")
                        .font(.splatoonFont1(size: 12))
                    Rectangle()
                        .foregroundColor(.clear)
                        .overlay(
                            coop.gradeDiff?.image,
                            alignment: .leading
                        )
                        .frame(width: 13, height:13)
                        .padding([.top, .bottom], 0.5)
                }else if coop.rule == .teamContest{
                    HStack(spacing: 3) {
                        Image(.golden)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                        Text("\(coop.goldenEgg)")
                            .font(.splatoonFont(size: 12))
                    }
                }else {
                    Text("-")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(Color(.clear))

                    Text("-")
                        .font(.splatoonFont1(size: 12))
                        .foregroundStyle(Color(.clear))
                    Rectangle()
                        .foregroundColor(.clear)
                        .overlay(
                            coop.gradeDiff?.image,
                            alignment: .leading
                        )
                        .frame(width: 13, height:13)
                        .padding([.top, .bottom], 0.5)
                }
                Spacer()
                
                // 喜爱按钮 - 只在被标记为喜爱时显示
                if isFavorite {
                    Button(action: {
                        toggleFavorite()
                    }) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8)
                }

                HStack {
                    Text(coop.stage.localizedFromSplatNet)
                        .font(.splatoonFont(size: 12))
                    if let boss = coop.boss,let defeated = coop.haveBossDefeated {
                        Text("/\(boss.localizedFromSplatNet)")
                            .font(.splatoonFont(size: 12))
                            .foregroundStyle(defeated ? Color.green : Color.orange)
                    }
                }
            }
            .padding(.bottom,3)

            HStack {
                Text(clear ? "Clear!!" : "Failure")
                    .font(.splatoonFont1(size: 14))

                Spacer()

                HStack {
                    HStack(spacing: 3){
                        Image(.salmonRun)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(coop.enemyDefeatCount)")
                            .font(.splatoonFont(size: 10))

                    }

                    HStack(spacing: 3){
                        coop._specie.coopRescue
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("\(coop.rescue)")
                            .font(.splatoonFont(size: 10))

                    }

                    HStack(spacing: 3){
                        coop._specie.coopRescued
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("\(coop.rescued)")
                            .font(.splatoonFont(size: 10))

                    }

                    if coop.rule != .teamContest{
                        HStack(spacing: 3) {
                            Image(.golden)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                            Text("\(coop.goldenEgg)")
                                .font(.splatoonFont(size: 10))
                        }
                    }

                    HStack(spacing: 3) {
                        Image(.egg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(coop.powerEgg)")
                            .font(.splatoonFont(size: 10))
                    }

                }
                .layoutPriority(1)
            }
            .padding(.bottom, 3)

            HStack{
                ForEach(Array(1...coop.rule.waveCount), id: \.self){index in
                    Rectangle()
                        .foregroundColor(coop.resultWave >= index ? clear ? Color.green : Color.orange : Color(.systemGray3))
                        .frame(height: 5)
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text("危险度").font(.splatoonFont(size: 10))+Text(dangerRateText)
                    .font(.splatoonFont(size: 10))
                Spacer()
                Text("\(coop.time.toPlayedTimeString())")
                    .font(.splatoonFont(size: 10))
            }
            .foregroundColor(Color(.systemGray2))
            .padding(.top, 1)
        }
        .padding(.top, 7.5)
        .padding(.bottom, 7)
        .padding([.leading, .trailing], 8)
        .background(Color(.listItemBackground))
        .frame(height: 85)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 10))
        .contextMenu{
            Button{
                toggleFavorite()
            } label: {
                Label(isFavorite ? "取消收藏" : "添加到收藏", systemImage: isFavorite ? "heart.slash.fill" : "heart.fill")
            }
            
            Button{
                showDeleteAlert = true
            } label: {
                Label("删除", systemImage: "trash")
            }
            .foregroundColor(.red)
            
            Divider()
            
            Button{
                let image = CoopListDetailView(isCoop: true, coopId: coop.id, shiftId: nil).asUIImage(size: CGSize(width: 400, height: coop.height))
                let activityController = UIActivityViewController(
                    activityItems: [image], applicationActivities: nil)
                let vc = UIApplication.shared.windows.first!.rootViewController
                vc?.present(activityController, animated: true)
            } label: {
                Label("保存至相册", systemImage: "photo.on.rectangle")
            }
        }
        .padding([.leading, .trailing])
        .padding(.top,3)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                softDeleteCoop()
            }
        } message: {
            Text("此操作会将记录移动到回收站，可以恢复。")
        }
        .onAppear {
            loadCoopData()
        }
    }
    
    // MARK: - 方法
    private func loadCoopData() {
        // 从数据库获取最新的isFavorite和isDeleted状态
        Task {
            do {
                if let actualCoop = try await SplatDatabase.shared.dbQueue.read({ db in
                    try Coop.fetchOne(db, key: coop.id)
                }) {
                    await MainActor.run {
                        self.isFavorite = actualCoop.isFavorite
                        self.isDeleted = actualCoop.isDeleted
                    }
                }
            } catch {
                print("Error loading coop data: \(error)")
            }
        }
    }
    
    private func toggleFavorite() {
        Task {
            do {
                if let actualCoop = try await SplatDatabase.shared.dbQueue.read({ db in
                    try Coop.fetchOne(db, key: coop.id)
                }) {
                    try actualCoop.toggleFavorite()
                    await MainActor.run {
                        self.isFavorite.toggle()
                    }
                }
            } catch {
                print("Error toggling favorite: \(error)")
            }
        }
    }
    
    private func softDeleteCoop() {
        Task {
            do {
                if let actualCoop = try await SplatDatabase.shared.dbQueue.read({ db in
                    try Coop.fetchOne(db, key: coop.id)
                }) {
                    try actualCoop.softDelete()
                    // 可以发送通知让列表刷新
                    NotificationCenter.default.post(name: .coopDataChanged, object: nil)
                }
            } catch {
                print("Error deleting coop: \(error)")
            }
        }
    }

}

// MARK: - 通知扩展
extension Notification.Name {
    static let coopDataChanged = Notification.Name("coopDataChanged")
}

//#Preview {
//    CoopListDetailItemView(coop: CoopListRowInfo(id: 1, rule: .regular , grade: 8, gradePoint: 999, gradeDiff: .up, dangerRate: 3.33,enemyDefeatCount:21, specie:true, stage: "Q29vcFN0YWdlLTk=", boss: "Q29vcEVuZW15LTIz", haveBossDefeated: true, resultWave: 3, goldenEgg: 212, powerEgg: 5341, rescue: 1, rescued: 0, time: Date.init(timeInterval: -30000000, since: Date()),GroupId: 0))
//        .padding(.top, 8)
//        .padding([.leading, .trailing])
//        .frame(width: 370)
//        .previewLayout(.sizeThatFits)
//}
