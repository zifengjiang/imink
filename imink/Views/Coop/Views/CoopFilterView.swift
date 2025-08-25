import SwiftUI
import SplatDatabase

//struct Filter {
//    var modes: [String] 
//    var rules: [String]?
//    var stageIds: [Int]?
//    var weaponIds: [Int]?
//    var start: Date?
//    var end: Date?
//}

extension ImageMap {
    var weaponType: String {
        let parts = name.split(separator: "_")
        return parts.count > 1 ? String(parts[1]) : "Unknown"
    }
}


class CoopFilterViewModel: ObservableObject {
    @Published var weaponsByType: [String: [ImageMap]] = [:]

    func load() async {
        let weapons = try! await SplatDatabase.shared.dbQueue.read { db in
            try ImageMap.fetchAll(db, sql:"""
                                SELECT *
                                FROM imageMap
                                WHERE name LIKE 'Wst%'
                                AND name NOT LIKE '%_O'
                                AND name NOT LIKE '%01'
                                AND name NOT LIKE '%Scope_00'
                                AND name != 'Wst_Shooter_Normal_H'
                                ORDER BY name ASC
                                """)
        }

            // 分组
        let grouped = Dictionary(grouping: weapons, by: \.weaponType)

        await MainActor.run {
            self.weaponsByType = grouped
        }
    }
}


struct CoopFilterView:View {
    @StateObject var viewModel = CoopFilterViewModel()
    
    @Binding var showFilterView: Bool
    @Binding var filter: Filter

    var onDismiss: () async -> Void

    var body: some View {
        NavigationStack{
            ScrollView {
                VStack(alignment: .leading) {
                    DatePicker("开始时间", selection: $filter.start, displayedComponents: [.date,.hourAndMinute])
                    DatePicker("结束时间", selection: $filter.end, displayedComponents: [.date,.hourAndMinute])
                    
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
                                set: { value in
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
