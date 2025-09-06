import SwiftUI
import SplatDatabase
import GRDB


extension ImageMap {
    var weaponType: String {
        let parts = name.split(separator: "_")
        return parts.count > 1 ? String(parts[1]) : "Unknown"
    }
}

struct PlayerSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let byname: String
    let nameId: String
    let playCount: Int

    var displayName: String {
        if byname.isEmpty {
            return name
        } else {
            return "\(name) (\(byname))"
        }
    }
}


class CoopFilterViewModel: ObservableObject {
    @Published var weaponsByType: [String: [ImageMap]] = [:]
    @Published var searchResults: [PlayerSearchResult] = []
    @Published var isSearching: Bool = false
    @Published var stages: [ImageMap] = [] // 新增地图数据

    func load() async {
        let weapons = try! await SplatDatabase.shared.dbQueue.read { db in
            try ImageMap.fetchAll(db, sql:"""
                                SELECT DISTINCT im.*
                                FROM imageMap im
                                INNER JOIN weapon w ON im.id = w.imageMapId
                                INNER JOIN coopPlayerResult cpr ON w.coopPlayerResultId = cpr.id
                                INNER JOIN coop c ON cpr.coopId = c.id
                                WHERE cpr.'order' = 0
                                AND c.accountId = ?
                                AND im.name LIKE 'Wst%'
                                AND im.name NOT LIKE '%_O'
                                AND im.name NOT LIKE '%01'
                                AND im.name NOT LIKE '%Scope_00'
                                AND im.name != 'Wst_Shooter_Normal_H'
                                ORDER BY im.name ASC
                                """, arguments: [AppUserDefaults.shared.accountId])
        }

            // 加载地图数据
        let stages = try! await SplatDatabase.shared.dbQueue.read { db in
            try ImageMap.fetchAll(db, sql: """
                SELECT DISTINCT im.*
                FROM imageMap im
                INNER JOIN coop c ON im.id = c.stageId
                WHERE c.accountId = ?
                ORDER BY im.name ASC
            """, arguments: [AppUserDefaults.shared.accountId])
        }

            // 分组
        let grouped = Dictionary(grouping: weapons, by: \.weaponType)

        await MainActor.run {
            self.weaponsByType = grouped
            self.stages = stages
        }
    }

    func searchPlayers(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
            return
        }

        await MainActor.run {
            self.isSearching = true
        }

        let results = try! await SplatDatabase.shared.dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT 
                    player.name,
                    player.byname,
                    player.nameId,
                    COUNT(DISTINCT coop.id) as playCount
                FROM player
                INNER JOIN coopPlayerResult ON player.coopPlayerResultId = coopPlayerResult.id
                INNER JOIN coop ON coopPlayerResult.coopId = coop.id
                WHERE coop.accountId = ?
                AND (player.name LIKE ? OR player.byname LIKE ?)
                AND player.isMyself != 1
                GROUP BY player.name, player.byname, player.nameId
                HAVING playCount > 0
                ORDER BY playCount DESC, player.name ASC
                LIMIT 20
            """, arguments: [AppUserDefaults.shared.accountId, "%\(query)%", "%\(query)%"])
        }.map { row in
            PlayerSearchResult(
                name: row["name"],
                byname: row["byname"],
                nameId: row["nameId"],
                playCount: row["playCount"]
            )
        }

        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
        }
    }
}


struct CoopFilterView:View {
    @StateObject var viewModel = CoopFilterViewModel()
    @State private var searchText: String = ""

    @Binding var showFilterView: Bool
    @Binding var filter: Filter

    var onDismiss: () async -> Void

    var body: some View {
        NavigationStack{
            ScrollView {
                VStack(alignment: .leading) {
                        // 时间范围选择
                    VStack(alignment: .center, spacing: 12) {
                        Text("时间范围")
                            .font(.splatoonFont(size: 18))

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("开始时间")
                                    .font(.splatoonFont(size: 14))
                                    .foregroundColor(.secondary)
                                Text(filter.start, style: .date)
                                    .font(.splatoonFont(size: 16))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("结束时间")
                                    .font(.splatoonFont(size: 14))
                                    .foregroundColor(.secondary)
                                Text(filter.end, style: .date)
                                    .font(.splatoonFont(size: 16))
                            }
                        }

                            // 时间范围滑块
                        TimeRangeSlider(
                            lineWidth: UIScreen.main.bounds.width - 64,
                            minDate: getCoopEarliestPlayedTime(),
                            maxDate: Date(),
                            startDate: $filter.start,
                            endDate: $filter.end
                        )
                        .frame(height: 30)

                            // 显示时间间隔（调试用）
                        let timeInterval = filter.end.timeIntervalSince(filter.start)
                        let days = Int(timeInterval / (24 * 3600))
                        let hours = Int((timeInterval.truncatingRemainder(dividingBy: 24 * 3600)) / 3600)
                        Text("时间间隔: \(days)天\(hours)小时")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()
                        .padding(.vertical, 8)

                        // 记录状态过滤
                    VStack(alignment: .leading, spacing: 12) {
                        Text("记录状态")
                            .font(.splatoonFont(size: 18))

                        Toggle("只显示收藏", isOn: $filter.showOnlyFavorites)

                        HStack {
                            Text("显示模式:")
                            Spacer()
                            Picker("显示模式", selection: Binding(
                                get: {
                                    if filter.showDeleted && !filter.showOnlyActive {
                                        return 1 // 只显示已删除
                                    } else if filter.showDeleted && filter.showOnlyActive {
                                        return 2 // 显示全部
                                    } else {
                                        return 0 // 只显示活跃
                                    }
                                },
                                set: { (value: Int) in
                                    switch value {
                                    case 0: // 只显示活跃
                                        filter.showOnlyActive = true
                                        filter.showDeleted = false
                                    case 1: // 只显示已删除
                                        filter.showOnlyActive = false
                                        filter.showDeleted = true
                                    case 2: // 显示全部
                                        filter.showOnlyActive = true
                                        filter.showDeleted = true
                                    default:
                                        break
                                    }
                                }
                            )) {
                                Text("活跃记录").tag(0)
                                Text("已删除").tag(1)
                                Text("全部记录").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)

                        // 玩家筛选
                    VStack(alignment: .leading, spacing: 12) {
                        Text("玩家筛选")
                            .font(.splatoonFont(size: 18))

                            // 搜索玩家
                        VStack(alignment: .leading, spacing: 8) {
                            Text("搜索玩家")
                                .font(.splatoonFont(size: 14))
                                .foregroundColor(.secondary)

                            HStack {
                                TextField("输入玩家名称或昵称", text: $searchText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onChange(of: searchText) { _, newValue in
                                        Task {
                                            await viewModel.searchPlayers(query: newValue)
                                        }
                                    }

                                if viewModel.isSearching {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }

                                // 搜索结果
                            if !viewModel.searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("搜索结果")
                                        .font(.splatoonFont(size: 12))
                                        .foregroundColor(.secondary)

                                    ForEach(viewModel.searchResults) { result in
                                        Button(action: {
                                            filter.playerName = result.name
                                            filter.playerByname = result.byname
                                            filter.playerNameId = result.nameId
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(result.displayName)
                                                        .font(.splatoonFont(size: 14))
                                                        .foregroundColor(.primary)
                                                    Text("打工次数: \(result.playCount)")
                                                        .font(.splatoonFont(size: 12))
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                if filter.playerName == result.name &&
                                                    filter.playerByname == result.byname &&
                                                    filter.playerNameId == result.nameId {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.accentColor)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)

                            // 手动输入筛选条件
                        VStack(alignment: .leading, spacing: 8) {
                            Text("手动输入筛选条件")
                                .font(.splatoonFont(size: 14))
                                .foregroundColor(.secondary)

                            Text("玩家名称")
                                .font(.splatoonFont(size: 12))
                                .foregroundColor(.secondary)

                            TextField("输入玩家名称", text: Binding(
                                get: { filter.playerName ?? "" },
                                set: { filter.playerName = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                            Text("玩家昵称")
                                .font(.splatoonFont(size: 12))
                                .foregroundColor(.secondary)

                            TextField("输入玩家昵称", text: Binding(
                                get: { filter.playerByname ?? "" },
                                set: { filter.playerByname = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                            Text("玩家ID")
                                .font(.splatoonFont(size: 12))
                                .foregroundColor(.secondary)

                            TextField("输入玩家ID", text: Binding(
                                get: { filter.playerNameId ?? "" },
                                set: { filter.playerNameId = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }

                            // 清除玩家筛选按钮
                        if filter.playerName != nil || filter.playerByname != nil || filter.playerNameId != nil {
                            Button("清除玩家筛选") {
                                filter.playerName = nil
                                filter.playerByname = nil
                                filter.playerNameId = nil
                            }
                            .foregroundColor(.red)
                            .font(.splatoonFont(size: 14))
                        }
                    }
                    .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)

                        // 地图筛选
                    VStack(alignment: .leading, spacing: 12) {
                        Text("地图筛选")
                            .font(.splatoonFont(size: 18))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                            ForEach(viewModel.stages, id: \.hash) { stage in
                                Button {
                                    if filter.stageIds.contains(Int(stage.id!)) {
                                        filter.stageIds.remove(Int(stage.id!))
                                    } else {
                                        filter.stageIds.insert(Int(stage.id!))
                                    }
                                } label: {
                                    VStack {
                                        Image(stage.name)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 100)
                                            .overlay(filter.stageIds.contains(Int(stage.id!)) ? Color.accent.opacity(0.5) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        Text(stage.nameId.localizedFromSplatNet)
                                            .font(.splatoonFont(size: 12))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.3)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    Divider()
                        .padding(.vertical, 8)

                    ForEach(viewModel.weaponsByType.keys.sorted(), id: \.self) { type in
                        VStack(alignment: .leading) {
                            Text(type)
                                .font(.splatoonFont(size: 22))
                                //                                .padding(.leading)


                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                                ForEach(viewModel.weaponsByType[type]!, id: \.hash) { weapon in
                                    Button {
                                        if filter.weaponIds.contains(Int(weapon.id!)) {
                                            filter.weaponIds.remove(Int(weapon.id!))
                                        } else {
                                            filter.weaponIds.insert(Int(weapon.id!))
                                        }
                                    } label: {
                                        Image(weapon.name)
                                            .resizable()
                                            .scaledToFit()
                                            .background(filter.weaponIds.contains(Int(weapon.id!)) ? Color.accent.opacity(0.5) : Color.gray.opacity(0.3))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                        .padding(.bottom)
                    }
                }
                .padding()
            }

            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showFilterView = false
                        Task{
                            await onDismiss()
                        }
                    }) {
                        Text("setting_page_done")
                            .foregroundStyle(.accent)
                            .frame(height: 40)
                    }
                }
            }
            .task {
                await viewModel.load()
            }
        }

    }
}

extension CoopFilterViewModel {

    static let preview = CoopFilterViewModel()
}

#Preview {
    CoopFilterView(viewModel: .preview, showFilterView: .constant(true), filter: .constant(Filter())) {

    }
}
