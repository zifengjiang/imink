//
//  BattleListDetailItemView.swift
//  imink
//
//  Created by 姜锋 on 2025/8/16.
//

import SwiftUI
import SplatDatabase

struct BattleListDetailItemView: View {
    let detail:BattleListRowInfo
    @State private var showDeleteAlert = false
    @State private var isFavorite: Bool = false
    @State private var isDeleted: Bool = false
    var mode:BattleMode{detail.mode}
    var rule:BattleRule{detail.rule}
    var species:Species{detail.species ? Species.INKLING : Species.OCTOLING}
    var ratios:[Double]{
        let r = getRatio(scores: detail.scores, ratios: detail.ratios, count: detail.colors.count)
        var res = [Double]()
        _ = r.reduce(0){ sum, cur in
            let newSum = sum + cur
            res.append(newSum)
            return newSum
        }
        return res
    }

    var body: some View {
        ZStack {
            VStack(spacing:0){
                HStack(spacing:6){
                    if mode == .fest{
                        FestIcon()
                            .frame(width: 16, height: 16)
                            .padding(.top, -0.5)
                            .padding(.bottom, -1.5)
                    }else{
                        mode.icon
                            .resizable()
                            .frame(width: 16, height: 16)
                            .padding(.top, -0.5)
                            .padding(.bottom, -1.5)
                    }

                    Text(rule.name)
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(mode.color)
                    Spacer()
                    
                    // 喜爱按钮
                    Button(action: {
                        toggleFavorite()
                    }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(isFavorite ? .red : .gray)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8)

                    if mode == .anarchy{
                        HStack(alignment: .firstTextBaseline, spacing: 0){
                            Text(detail.udemae ?? "C-")
                                .font(.splatoonFont(size: 12))
                            if let plus = detail.earnedUdemaePoint{
                                Text("\(plus)")
                                    .font(.splatoonFont(size: 8))
                                    .padding(.leading,0.6)
                                    //                  .padding(.bottom, 0)
                            }
                        }
                    }
                }
                .padding(.bottom, 6.5)

                HStack {
                    Text(detail.judgement.name)
                        .font(.splatoonFont(size: 14))
                        .foregroundStyle(detail.judgement.color)
                    if let k = detail.knockout, k == .WIN {
                        Text("完胜!")
                            .font(.splatoonFont(size: 14))
                            .foregroundStyle(.spYellow)
                    }else if rule != .turfWar && rule != .triColor{
                        Text("\(detail.point)计数")
                            .font(.splatoonFont(size: 14))
                            .foregroundStyle(detail.judgement == .LOSE ? Color.secondary : .spGreen)
                    }else {
                        Text("\(detail.point)p")
                            .font(.splatoonFont(size: 14))
                            .foregroundStyle(detail.judgement == .LOSE ? Color.secondary : .spGreen)
                    }
                    Spacer()
                    HStack{
                        HStack(spacing:3){
                            species.icon.kill
                                .resizable()
                                .frame(width: 14, height: 14)
                                .foregroundColor(.gray)
                            HStack(alignment: .firstTextBaseline, spacing: 0){
                                Text("\((detail.kill) + (detail.assist))")
                                    .font(.splatoonFont(size: 10))
                                Text("(\(detail.assist))")
                                    .font(.splatoonFont(size: 7))
                            }
                        }

                        HStack(spacing: 3) {
                            species.icon.dead
                                .resizable()
                                .frame(width: 14, height: 14)
                                .foregroundColor(.gray)
                            Text("\(detail.death)")
                                .font(.splatoonFont(size: 10))
                        }

                        HStack(spacing: 3) {
                            species.icon.kd
                                .resizable()
                                .frame(width: 14, height: 14)
                                .foregroundColor(.gray)
                            let death = detail.death
                            Text("\(Double(detail.kill) -/ Double(death == 0 ? 1 : death), places: 1)")
                                .font(.splatoonFont(size: 10))
                        }
                    }
                }
                .padding(.bottom, 7)

                HStack(spacing: 0) {
                    GeometryReader { geo in
                        Rectangle()
                            .foregroundStyle(Color.gray)
                            //                        Rectangle()
                            //                            .foregroundColor(detail.judgement.color)
                            //                            .frame(width: geo.size.width*myPoint)
                        ForEach(ratios.indices.reversed(), id: \.self){ index in
                            Rectangle()
                                .foregroundColor(detail.colors[index].toColor())
                                .frame(width: geo.size.width*ratios[index])
                        }


                    }
                }
                .frame(height: 5)
                .clipShape(Capsule())
                .padding(.bottom, 6)

                HStack{
                    Text(detail.stage.localizedFromSplatNet)
                        .font(.splatoonFont(size: 10))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text(detail.playedTime.toPlayedTimeString(full: true))
                        .font(.splatoonFont(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }


            VStack {
                if let weapon = detail._weapon{
                    Image(weapon.mainWeapon.name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
            .padding(.top, 6.5)
        }
        .padding(.top, 7.5)
        .padding(.bottom, 7)
        .padding([.leading, .trailing], 8)
        .background(Color(.listItemBackground))
        .frame(height: 85)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        }
        .padding([.leading, .trailing])
        .padding(.top,3)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                softDeleteBattle()
            }
        } message: {
            Text("此操作会将记录移动到回收站，可以恢复。")
        }
        .onAppear {
            loadBattleData()
        }
    }
    
    // MARK: - 方法
    private func loadBattleData() {
        // 从数据库获取最新的isFavorite和isDeleted状态
        Task {
            do {
                if let actualBattle = try await SplatDatabase.shared.dbQueue.read({ db in
                    try Battle.fetchOne(db, key: detail.id)
                }) {
                    await MainActor.run {
                        self.isFavorite = actualBattle.isFavorite
                        self.isDeleted = actualBattle.isDeleted
                    }
                }
            } catch {
                print("Error loading battle data: \(error)")
            }
        }
    }
    
    private func toggleFavorite() {
        Task {
            do {
                if let actualBattle = try await SplatDatabase.shared.dbQueue.read({ db in
                    try Battle.fetchOne(db, key: detail.id)
                }) {
                    try actualBattle.toggleFavorite()
                    await MainActor.run {
                        self.isFavorite.toggle()
                    }
                }
            } catch {
                print("Error toggling favorite: \(error)")
            }
        }
    }
    
    private func softDeleteBattle() {
        Task {
            do {
                if let actualBattle = try await SplatDatabase.shared.dbQueue.read({ db in
                    try Battle.fetchOne(db, key: detail.id)
                }) {
                    try actualBattle.softDelete()
                    // 可以发送通知让列表刷新
                    NotificationCenter.default.post(name: .battleDataChanged, object: nil)
                }
            } catch {
                print("Error deleting battle: \(error)")
            }
        }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let battleDataChanged = Notification.Name("battleDataChanged")
}

//#Preview {
//    BattleListDetailItemView()
//}
