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


class CoopFilterViewModel: ObservableObject {
    @Published var weapons:[ImageMap] = []

    func load() async {
        try! await SplatDatabase.shared.dbQueue.read { db in
            let weapons = try ImageMap.fetchAll(db, sql:"""
                                SELECT *
                                FROM imageMap
                                WHERE name LIKE 'Wst%'
                                AND name NOT LIKE '%_O'
                                AND name NOT LIKE '%01'
                                AND name NOT LIKE '%Scope_00'
                                AND name != 'Wst_Shooter_Normal_H'
                                ORDER BY name ASC
                                """)
            DispatchQueue.main.async {
                self.weapons = weapons
            }
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
            ScrollView{
                VStack{
                    DatePicker("开始时间", selection: $filter.start, displayedComponents: [.date,.hourAndMinute])
                    DatePicker("结束时间", selection: $filter.end, displayedComponents: [.date,.hourAndMinute])
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8)) {
                        ForEach(viewModel.weapons, id: \.hash){ weapon in
                            Button {
                                if filter.weaponIds.contains(Int(weapon.id!)){
                                    filter.weaponIds.remove(Int(weapon.id!))
                                }else{
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


