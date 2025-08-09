import SwiftUI
import SplatDatabase

struct WeaponRecordView: View {
    @StateObject var viewModel = WeaponRecordViewModel()
    @State private var showingSortOptions = false
    
    var body: some View {
        VStack {
            if let weaponRecords = viewModel.weaponRecords {
                ScrollView(.vertical) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(120),spacing: 10), count: 3)) {
                        ForEach(viewModel.sortedRecords, id: \.name.nameId) { record in
                            RecordView(record: record)
                        }
                    }
                }
            } else {
                LoadingView(size: 100)
            }
        }
        .navigationTitle("武器记录")
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .fixSafeareaBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSortOptions = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .confirmationDialog("更改排序", isPresented: $showingSortOptions, titleVisibility: .visible) {
            Button("常用武器") { viewModel.sortBy = .frequentlyUsed }
            Button("主要武器") { viewModel.sortBy = .mainWeapon }
            Button("次要武器") { viewModel.sortBy = .subWeapon }
            Button("特殊武器") { viewModel.sortBy = .specialWeapon }
            Button("涂墨点数") { viewModel.sortBy = .paint }
            Button("熟练度") { viewModel.sortBy = .level }
            Button("距熟练度提升还剩") { viewModel.sortBy = .expToLevelUp }
            Button("胜利数") { viewModel.sortBy = .wins }
        }
    }

    struct RecordView: View {
        let record: WeaponRecord
        var body: some View {
            GeometryReader { proxy in
                VStack(spacing: proxy.size.width/50){
                    HStack(spacing:0){
                        ForEach(0..<record.stats.level, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: proxy.size.width/12))
                        }
                        ForEach(record.stats.level..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.clear)
                                .font(.system(size: proxy.size.width/12))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: proxy.size.width/12)
                    .frame(alignment: .topTrailing)
                    Image(record.name.name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width * 0.8, height: proxy.size.width * 0.8)
                    HStack(spacing: proxy.size.width/30){
                        SpecialWeaponImage(imageName: record.subWeapon.name,size: proxy.size.width/8)
                            .padding(proxy.size.width/100)
                            .background(.black.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 3,style: .continuous))
                        SpecialWeaponImage(imageName: record.specialWeapon.name,size: proxy.size.width/8)
                            .padding(proxy.size.width/100)
                            .background(.black.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 3,style: .continuous))
                    }
                    .frame(maxWidth:.infinity,alignment: .leading)
                    .padding(.top,-proxy.size.width/13)
                    Text(record.name.nameId.localizedFromSplatNet)
                        .font(.splatoonFont(size: proxy.size.width/10))
                    VStack(alignment:.leading,spacing: proxy.size.width/60){
                        Text("胜利数 \(record.stats.win)")
                            .font(.splatoonFont(size: proxy.size.width/12))
                            .foregroundStyle(.secondary)
                        Text("涂墨点数 \(record.stats.paint)")
                            .font(.splatoonFont(size: proxy.size.width/12))
                            .foregroundStyle(.secondary)
                        Text("距熟练度提升还剩 \(record.stats.expToLevelUp)")
                            .font(.splatoonFont(size: proxy.size.width/12))
                            .foregroundStyle(.secondary)
                        Text("状态值 \(record.stats.vibes)")
                            .font(.splatoonFont(size: proxy.size.width/12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(proxy.size.width/30)
                .frame(width: proxy.size.width, alignment: .center)
                .textureBackground(texture: .bubble, radius: proxy.size.width/10)
            }
            .frame(width: 120,height: 185)
        }
    }
}

class WeaponRecordViewModel: ObservableObject {
    @Published var weaponRecords: WeaponRecords?
    @Published var sortBy: SortOption = .frequentlyUsed {
        didSet {
            objectWillChange.send()
        }
    }
    
    enum SortOption {
        case frequentlyUsed
        case mainWeapon
        case subWeapon
        case specialWeapon
        case paint
        case level
        case expToLevelUp
        case wins
    }
    
    var sortedRecords: [WeaponRecord] {
        guard let records = weaponRecords?.records else { return [] }
        
        switch sortBy {
        case .frequentlyUsed:
            return records.sorted { $0.stats.lastUsedTime ?? .distantPast > $1.stats.lastUsedTime ?? .distantPast }
        case .mainWeapon:
            return records.sorted { $0.name.nameId < $1.name.nameId }
        case .subWeapon:
            return records.sorted { $0.subWeapon.nameId < $1.subWeapon.nameId }
        case .specialWeapon:
            return records.sorted { $0.specialWeapon.nameId < $1.specialWeapon.nameId }
        case .paint:
            return records.sorted { $0.stats.paint > $1.stats.paint }
        case .level:
            return records.sorted { $0.stats.level > $1.stats.level }
        case .expToLevelUp:
            return records.sorted { $0.stats.expToLevelUp < $1.stats.expToLevelUp }
        case .wins:
            return records.sorted { $0.stats.win > $1.stats.win }
        }
    }
    
    init() {
        Task{@MainActor in
            await load()
        }
    }
    
    @MainActor
    func load() async {
        self.weaponRecords = await SN3Client.shared.fetchRecord(.weaponRecord)
    }
}
import SwiftyJSON

#Preview {
    HStack{
        WeaponRecordView.RecordView(record: WeaponRecord(name: .init(nameId: "V2VhcG9uLTA=", name: "Wst_Brush_Heavy_00", hash: ""), level: 3, win: 560, paint: 23123, subWeapon: .init(nameId: "U3ViV2VhcG9uLTY=", name: "Wsp_SpChariot", hash: ""), specialWeapon: .init(nameId: "U3BlY2lhbFdlYXBvbi0xMQ==", name: "Wsb_Bomb_Curling", hash: "")))
        WeaponRecordView.RecordView(record: WeaponRecord(name: .init(nameId: "V2VhcG9uLTA=", name: "Wst_Brush_Heavy_00", hash: ""), level: 3, win: 560, paint: 23123, subWeapon: .init(nameId: "U3ViV2VhcG9uLTY=", name: "Wsp_SpChariot", hash: ""), specialWeapon: .init(nameId: "U3BlY2lhbFdlYXBvbi0xMQ==", name: "Wsb_Bomb_Curling", hash: "")))
        WeaponRecordView.RecordView(record: WeaponRecord(name: .init(nameId: "V2VhcG9uLTA=", name: "Wst_Brush_Heavy_00", hash: ""), level: 3, win: 560, paint: 23123, subWeapon: .init(nameId: "U3ViV2VhcG9uLTY=", name: "Wsp_SpChariot", hash: ""), specialWeapon: .init(nameId: "U3BlY2lhbFdlYXBvbi0xMQ==", name: "Wsb_Bomb_Curling", hash: "")))
    }
}

extension WeaponRecord {
    init(name: ImageMap, level: Int, win: Int, paint: Int, subWeapon: ImageMap, specialWeapon: ImageMap) {
        self.name = name
        self.stats = Stats(expToLevelUp: 0, vibes: 0, level: level, win: win, paint: paint, lastUsedTime: nil)
        self.subWeapon = subWeapon
        self.specialWeapon = specialWeapon
        self.category = 0
    }
}

extension WeaponRecord.Stats {
    init(expToLevelUp: Int, vibes: Int, level: Int, win: Int, paint: Int, lastUsedTime: Date?) {
        self.expToLevelUp = expToLevelUp
        self.vibes = vibes
        self.level = level
        self.win = win
        self.paint = paint
        self.lastUsedTime = lastUsedTime
    }
}

