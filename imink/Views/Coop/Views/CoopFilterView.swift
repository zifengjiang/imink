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
