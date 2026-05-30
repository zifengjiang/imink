import SwiftUI

struct MePage: View {
    @ObservedObject private var appState = AppState.shared

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack{
            List {
                Section {
                    AccountReviewView()

                    if appState.isLogin {
                        FriendsView()
                            .padding(.vertical, 6)
                    }
                }

                Section("记录概览") {
                    LazyVGrid(columns: summaryColumns, spacing: 12) {
                        ForEach(summaryMetrics) { metric in
                            SWKPICard(
                                title: LocalizedStringKey(metric.title),
                                value: metric.value,
                                icon: metric.icon,
                                tint: tint(for: metric.kind)
                            ) {
                                Text(metric.caption)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section("我的记录") {
                    NavigationLink("打工记录", destination: CoopRecordView())
                    NavigationLink("祭典记录", destination: CoopRecordView())
                    NavigationLink("场地记录", destination: StageRecordView())
                    NavigationLink("武器记录", destination: WeaponRecordView())
                }
                
                Section("个性化") {
                    NavigationLink("铭牌编辑器", destination: NameplateEditorView())
                        .foregroundColor(.primary)
                }
                
                Section("数据管理") {
                    NavigationLink("回收站", destination: TrashView())
                        .foregroundColor(.primary)
                }
                
                #if DEBUG
                Section("开发测试") {
                    NavigationLink("设备方向测试", destination: OrientationTestView())
                        .foregroundColor(.primary)
                }
                #endif
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

    private var summaryMetrics: [MeSummaryMetric] {
        MeSummaryMetric.recordCounts(
            battleCount: appState.battleRecordsCount,
            salmonRunCount: appState.salmonRunRecordsCount
        )
    }

    private func tint(for kind: MeSummaryMetric.Kind) -> Color {
        switch kind {
        case .battle:
            return .spOrange
        case .salmonRun:
            return .spGreen
        }
    }
}

#Preview {
    MePage()
}
