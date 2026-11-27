import SwiftUI
import SplatDatabase

struct TrashView: View {
    @StateObject private var viewModel = TrashViewModel()
    @State private var selectedTab = 0

    /// 当前标签对应的记录类型。
    private var selectedKind: SplatRecordKind {
        selectedTab == 0 ? .coop : .battle
    }

    private var isCurrentEmpty: Bool {
        selectedTab == 0 ? viewModel.deletedCoops.isEmpty : viewModel.deletedBattles.isEmpty
    }

    private var typePicker: some View {
        Picker("类型", selection: $selectedTab) {
            Text("鲑鱼跑").tag(0)
            Text("对战").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var recordList: some View {
        if isCurrentEmpty {
            VStack(spacing: 12) {
                Image(systemName: "trash")
                    .font(.appDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, height: 64)
                    .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(selectedTab == 0 ? "暂无已删除的打工记录" : "暂无已删除的对战记录")
                    .font(.appHeadline)
                    .foregroundStyle(.appLabel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if selectedTab == 0 {
                        ForEach(viewModel.deletedCoops, id: \.id) { coop in
                            DeletedCoopRowView(coop: coop)
                        }
                    } else {
                        ForEach(viewModel.deletedBattles, id: \.id) { battle in
                            DeletedBattleRowView(battle: battle)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
    }

    private func restoreAll() {
        Task { await viewModel.restoreAll(kind: selectedKind) }
    }

    private func permanentlyDeleteAll() {
        Task { await viewModel.permanentlyDeleteAll(kind: selectedKind) }
    }

    var body: some View {
        VStack(spacing: 0) {
            typePicker
            recordList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("回收站")
        .navigationBarTitleDisplayMode(.inline)
        .fixSafeareaBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("恢复全部") {
                        restoreAll()
                    }
                    .disabled(isCurrentEmpty)

                    Button("永久删除全部", role: .destructive) {
                        viewModel.showPermanentDeleteAlert = true
                    }
                    .disabled(isCurrentEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("永久删除确认", isPresented: $viewModel.showPermanentDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("永久删除", role: .destructive) {
                permanentlyDeleteAll()
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

/// 回收站一行：统一卡片外观 + 恢复 / 永久删除操作。
struct DeletedRecordRow<Content: View>: View {
    let kind: SplatRecordKind
    let recordId: Int64
    private let content: Content

    @State private var showRestoreAlert = false

    init(kind: SplatRecordKind, recordId: Int64, @ViewBuilder content: () -> Content) {
        self.kind = kind
        self.recordId = recordId
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contextMenu {
                Button("恢复") {
                    showRestoreAlert = true
                }

                Button("永久删除", role: .destructive) {
                    Task { await permanentlyDelete() }
                }
            }
            .alert("恢复记录", isPresented: $showRestoreAlert) {
                Button("取消", role: .cancel) {}
                Button("恢复") {
                    Task { await restore() }
                }
            } message: {
                Text("确定要恢复这条记录吗？")
            }
            .padding(.horizontal, 16)
    }

    private func restore() async {
        do {
            try await RecordStore.restore(ids: [recordId], kind: kind)
        } catch {
            logError(error)
            Toast.failure("恢复失败", subtitle: error.localizedDescription)
        }
    }

    private func permanentlyDelete() async {
        do {
            try await RecordStore.permanentlyDelete(ids: [recordId], kind: kind)
        } catch {
            logError(error)
            Toast.failure("删除失败", subtitle: error.localizedDescription)
        }
    }
}

struct DeletedCoopRowView: View {
    let coop: Coop

    var body: some View {
        DeletedRecordRow(kind: .coop, recordId: coop.id ?? 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(coop.rule.localizedFromSplatNet)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)

                    Text(coop.clear ? "Clear!!" : "Failure")
                        .font(.appGameSubhead)
                        .foregroundStyle(coop.clear ? Color.waveClear : Color.waveDefeat)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("金蛋 \(coop.egg)")
                        .font(.appMono)
                        .foregroundStyle(.appLabel)
                    Text(coop.playedTime.toPlayedTimeString())
                        .font(.appCaptionMono)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DeletedBattleRowView: View {
    let battle: Battle

    var body: some View {
        DeletedRecordRow(kind: .battle, recordId: battle.id ?? 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text((BattleMode(rawValue: battle.mode)?.name) ?? battle.mode)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)

                    Text(battle.judgement.localizedFromSplatNet)
                        .font(.appGameSubhead)
                        .foregroundStyle(battle.judgement == "WIN" ? Color.spLightGreen : Color.spPink)
                }

                Spacer()

                Text(battle.playedTime.toPlayedTimeString())
                    .font(.appCaptionMono)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TrashView()
    }
}
