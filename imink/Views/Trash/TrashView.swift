import SwiftUI
import SplatDatabase

struct TrashView: View {
    @StateObject private var viewModel = TrashViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                // 标签切换
                Picker("类型", selection: $selectedTab) {
                    Text("鲑鱼跑").tag(0)
                    Text("对战").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 列表内容
                ScrollView {
                    LazyVStack {
                        if selectedTab == 0 {
                            // 鲑鱼跑回收站
                            ForEach(viewModel.deletedCoops, id: \.id) { coop in
                                DeletedCoopRowView(coop: coop)
                            }
                        } else {
                            // 对战回收站
                            ForEach(viewModel.deletedBattles, id: \.id) { battle in
                                DeletedBattleRowView(battle: battle)
                            }
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationTitle("回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("恢复全部") {
                            Task {
                                await viewModel.restoreAll(type: selectedTab == 0 ? .coop : .battle)
                            }
                        }
                        
                        Button("永久删除全部", role: .destructive) {
                            viewModel.showPermanentDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("永久删除确认", isPresented: $viewModel.showPermanentDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("永久删除", role: .destructive) {
                    Task {
                        await viewModel.permanentDeleteAll(type: selectedTab == 0 ? .coop : .battle)
                    }
                }
            } message: {
                Text("此操作无法恢复，确定要永久删除所有回收站中的记录吗？")
            }
            .task {
                await viewModel.loadData()
            }
            .onChange(of: selectedTab) { _, _ in
                Task {
                    await viewModel.loadData()
                }
            }
        }
    }
}

struct DeletedCoopRowView: View {
    let coop: Coop
    @State private var showRestoreAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(coop.rule.localizedFromSplatNet)
                        .font(.splatoonFont(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(coop.clear ? "Clear!!" : "Failure")
                        .font(.splatoonFont1(size: 14))
                        .foregroundColor(coop.clear ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("金蛋: \(coop.egg)")
                        .font(.splatoonFont(size: 12))
                    Text("\(coop.playedTime.toPlayedTimeString())")
                        .font(.splatoonFont(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .contextMenu {
            Button("恢复") {
                showRestoreAlert = true
            }
            
            Button("永久删除", role: .destructive) {
                Task {
                    do {
                        try SplatDatabase.shared.dbQueue.write { db in
                            try coop.delete(db)
                        }
                        NotificationCenter.default.post(name: .coopDataChanged, object: nil)
                    } catch {
                        print("Error permanently deleting coop: \(error)")
                    }
                }
            }
        }
        .alert("恢复记录", isPresented: $showRestoreAlert) {
            Button("取消", role: .cancel) {}
            Button("恢复") {
                Task {
                    do {
                        try coop.restore()
                        NotificationCenter.default.post(name: .coopDataChanged, object: nil)
                    } catch {
                        print("Error restoring coop: \(error)")
                    }
                }
            }
        } message: {
            Text("确定要恢复这条记录吗？")
        }
        .padding(.horizontal)
    }
}

struct DeletedBattleRowView: View {
    let battle: Battle
    @State private var showRestoreAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(battle.battleMode.name)
                        .font(.splatoonFont(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(battle.judgement.localizedFromSplatNet)
                        .font(.splatoonFont1(size: 14))
                        .foregroundColor(battle.judgement == "WIN" ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(battle.playedTime.toPlayedTimeString())")
                        .font(.splatoonFont(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .contextMenu {
            Button("恢复") {
                showRestoreAlert = true
            }
            
            Button("永久删除", role: .destructive) {
                Task {
                    do {
                        try SplatDatabase.shared.dbQueue.write { db in
                            try battle.delete(db)
                        }
                        NotificationCenter.default.post(name: .battleDataChanged, object: nil)
                    } catch {
                        print("Error permanently deleting battle: \(error)")
                    }
                }
            }
        }
        .alert("恢复记录", isPresented: $showRestoreAlert) {
            Button("取消", role: .cancel) {}
            Button("恢复") {
                Task {
                    do {
                        try battle.restore()
                        NotificationCenter.default.post(name: .battleDataChanged, object: nil)
                    } catch {
                        print("Error restoring battle: \(error)")
                    }
                }
            }
        } message: {
            Text("确定要恢复这条记录吗？")
        }
        .padding(.horizontal)
    }
}

#Preview {
    TrashView()
}
