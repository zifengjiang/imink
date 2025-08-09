import SwiftUI

struct StageRecordView: View {
    @StateObject var viewModel = StageRecordViewModel()
    @State var isShowingPopover = false

    var body: some View {
        VStack{
            if viewModel.stageRecords.count != 0 {
                ScrollView(.vertical){

                    VStack{
                        ForEach(viewModel.played.indices, id: \.self) { index in
                            if index & 1 != 1{
                                HStack{
                                    RecordRowView(stage: viewModel.played[index], sortedBy: $viewModel.sortedBy)
                                        .frame(width: 180, height: 180*0.92)
                                    if index + 1 < viewModel.played.count{
                                        RecordRowView(stage: viewModel.played[index + 1], sortedBy: $viewModel.sortedBy)
                                            .frame(width: 180, height: 180*0.92)
                                    }else{
                                        Rectangle()
                                            .fill(.clear)
                                            .frame(width: 180, height: 180*0.92)
                                    }
                                }
                            }
                        }
                        Text("未游玩的场地")
                            .font(.splatoonFont(size: 20))
                        ForEach(viewModel.notPlayed.indices, id: \.self) { index in
                            if index & 1 != 1{
                                HStack{
                                    RecordRowView(stage: viewModel.notPlayed[index], sortedBy: $viewModel.sortedBy)
                                        .frame(width: 180, height: 180*0.92)
                                    if index + 1 < viewModel.notPlayed.count{
                                        RecordRowView(stage: viewModel.notPlayed[index + 1], sortedBy: $viewModel.sortedBy)
                                            .frame(width: 180, height: 180*0.92)
                                    }else{
                                        Rectangle()
                                            .fill(.clear)
                                            .frame(width: 180, height: 180*0.92)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)

                }

                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Picker(selection: $viewModel.sortedBy) {
                            ForEach(StageRecordViewModel.SortedBy.allCases, id: \.self) { sortedBy in
                                Text(sortedBy.rawValue)
                                    .tag(sortedBy)
                            }
                        } label: {

                        }

                    }
                }
            }else{
                LoadingView(size: 100)
            }
        }
        .navigationTitle("场地记录")
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
        .fixSafeareaBackground()
        .task {
            await viewModel.fetchStageRecords()
        }
        .onChange(of: viewModel.sortedBy) { oldValue, newValue in
            viewModel.sort()
        }
    }


    struct RecordRowView:View {
        let stage:StageRecord
        @Binding var sortedBy: StageRecordViewModel.SortedBy
        let fontSize = 0.06
        var body: some View {
            GeometryReader{ proxy in
                VStack{
                    VStack(spacing: proxy.size.width * 0.02) {
                        Image(stage.name)
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                            .frame(width: proxy.size.width * 0.95, height: proxy.size.width * 9 / 16 * 0.95)
                            .clipShape(RoundedRectangle(cornerRadius: proxy.size.width * 0.04, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: proxy.size.width * 0.04)
                                    .stroke(Color(UIColor.separator), lineWidth: 1)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                Text(stage.nameId.localizedFromSplatNet)
                                    .font(.splatoonFont(size: proxy.size.width * 0.08))
                                    .padding(.horizontal, proxy.size.width * 0.014)
                                    .padding(.vertical, proxy.size.width * 0.007)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(proxy.size.width * 0.014)
                                    .padding(.trailing,proxy.size.width * 0.015)
                                    .padding(.bottom,proxy.size.width * 0.015)

                            }
                        HStack(alignment: .firstTextBaseline){
                            Text("上次游玩:")
                                .font(.splatoonFont(size: proxy.size.width*0.05))
                                .foregroundStyle(sortedBy == .time ? .spRed : .secondary)
                                .lineLimit(1)
                            Text("\((stage.stats?.lastPlayedTime ?? Date()).toPlayedTimeString(full: true))")
                                .font(.splatoonFont(size: proxy.size.width*0.05))
                                .foregroundStyle(sortedBy == .time ? .spRed : .secondary)
                                .lineLimit(1)
                        }

                    }



                    LazyVGrid(columns: [GridItem(.fixed(proxy.size.width*0.48)), GridItem(.fixed(proxy.size.width*0.48))],spacing: proxy.size.width*0.03){
                        HStack(alignment: .firstTextBaseline){
                            Text("占地对战")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .turf ? .spRed : .secondary)
                            Text(stage.stats?.winRateTw == nil ? "-": "\(100*(stage.stats?.winRateTw ?? 0.0), places: 1)%")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .turf ? .spRed : .secondary)
                        }

                        HStack(alignment: .firstTextBaseline){
                            Text("真格区域")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .area ? .spRed : .secondary)
                            Text(stage.stats?.winRateAr == nil ? "-": "\(100*(stage.stats?.winRateAr ?? 0.0), places: 1)%")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .area ? .spRed : .secondary)
                        }
                        HStack(alignment: .firstTextBaseline){
                            Text("真格塔楼")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .tower ? .spRed : .secondary)
                            Text(stage.stats?.winRateLf == nil ? "-": "\(100*(stage.stats?.winRateLf ?? 0.0), places: 1)%")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .tower ? .spRed : .secondary)
                        }

                        HStack(alignment: .firstTextBaseline){
                            Text("真格鱼虎")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .rain ? .spRed : .secondary)
                            Text(stage.stats?.winRateGl == nil ? "-": "\(100*(stage.stats?.winRateGl ?? 0.0), places: 1)%")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .rain ? .spRed : .secondary)
                        }

                        HStack(alignment: .firstTextBaseline){
                            Text("真格蛤蜊")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .clam ? .spRed : .secondary)
                            Text(stage.stats?.winRateCl == nil ? "-": "\(100*(stage.stats?.winRateCl ?? 0.0), places: 1)%")
                                .font(.splatoonFont(size: proxy.size.width*fontSize))
                                .foregroundStyle(sortedBy == .clam ? .spRed : .secondary)
                        }
                    }

                }
                .padding(.top, 10.5)
                .padding(.bottom, 7)
                .frame(width: proxy.size.width,height: proxy.size.width*0.92)
                .textureBackground(texture: .bubble, radius: proxy.size.width*0.06)
            }

        }
    }
}

class StageRecordViewModel: ObservableObject {
    @Published var stageRecords: [StageRecord] = []
    @Published var sortedBy: SortedBy = .time
    var notPlayed: [StageRecord] {
        stageRecords.filter {
            switch sortedBy {
            case .time:
                $0.stats?.winRateAr == nil && $0.stats?.winRateTw == nil && $0.stats?.winRateLf == nil && $0.stats?.winRateGl == nil && $0.stats?.winRateCl == nil
            case .area:
                $0.stats?.winRateAr == nil
            case .turf:
                $0.stats?.winRateTw == nil
            case .tower:
                $0.stats?.winRateLf == nil
            case .rain:
                $0.stats?.winRateGl == nil
            case .clam:
                $0.stats?.winRateCl == nil
            }
        }
    }

    var played: [StageRecord] {
        stageRecords.filter{
            switch sortedBy {
            case .time:
                $0.stats?.winRateAr != nil || $0.stats?.winRateTw != nil || $0.stats?.winRateLf != nil || $0.stats?.winRateGl != nil || $0.stats?.winRateCl != nil
            case .area:
                $0.stats?.winRateAr != nil
            case .turf:
                $0.stats?.winRateTw != nil
            case .tower:
                $0.stats?.winRateLf != nil
            case .rain:
                $0.stats?.winRateGl != nil
            case .clam:
                $0.stats?.winRateCl != nil
            }
        }
    }

    func fetchStageRecords() async {
        let records:[StageRecord] = await SN3Client.shared.fetchRecord(.stageRecord) ?? []
        DispatchQueue.main.async {
            self.stageRecords = records
            self.sort()
        }
    }

    func sortBy(_ by: SortedBy) {
        sortedBy = by
        sort()
    }

    func sort() {
        let sorted: [StageRecord]
            //        let sorted = stageRecords.sorted { (lhs, rhs) -> Bool in
            //            switch self.sortedBy {
            //            case .time:
            //                return lhs.stats?.lastPlayedTime ?? Date(timeIntervalSince1970: 0) > rhs.stats?.lastPlayedTime ?? Date(timeIntervalSince1970: 0)
            //            case .area:
            //                return lhs.stats?.winRateAr ?? 0 > rhs.stats?.winRateAr ?? 0
            //            case .turf:
            //                return lhs.stats?.winRateTw ?? 0 > rhs.stats?.winRateTw ?? 0
            //            case .tower:
            //                return lhs.stats?.winRateLf ?? 0 > rhs.stats?.winRateLf ?? 0
            //            case .rain:
            //                return lhs.stats?.winRateGl ?? 0 > rhs.stats?.winRateGl ?? 0
            //            case .clam:
            //                return lhs.stats?.winRateCl ?? 0 > rhs.stats?.winRateCl ?? 0
            //            }
            //        }
        switch sortedBy {
        case .time:
            sorted = stageRecords.sorted { (lhs, rhs) -> Bool in
                lhs.stats?.lastPlayedTime ?? Date(timeIntervalSince1970: 0) > rhs.stats?.lastPlayedTime ?? Date(timeIntervalSince1970: 0)
            }

        case .area:
            sorted = stageRecords.sorted { (lhs, rhs) -> Bool in
                lhs.stats?.winRateAr ?? 0 > rhs.stats?.winRateAr ?? 0
            }
        case .turf:
            sorted = stageRecords.sorted { (lhs, rhs) -> Bool in
                lhs.stats?.winRateTw ?? 0 > rhs.stats?.winRateTw ?? 0
            }

        case .tower:
            sorted = stageRecords.sorted { (lhs, rhs) -> Bool in
                lhs.stats?.winRateLf ?? 0 > rhs.stats?.winRateLf ?? 0
            }

        case .rain:
            sorted = stageRecords.sorted { (lhs, rhs) -> Bool in
                lhs.stats?.winRateGl ?? 0 > rhs.stats?.winRateGl ?? 0
            }

        case .clam:
            sorted = stageRecords.sorted { (lhs, rhs) -> Bool in
                lhs.stats?.winRateCl ?? 0 > rhs.stats?.winRateCl ?? 0
            }

        }

        withAnimation {
            stageRecords = sorted
        }
    }

    enum SortedBy:String, CaseIterable {
        case time = "上次游玩时间"
        case area = "真格区域"
        case turf = "占地对战"
        case tower = "真格塔楼"
        case rain = "真格鱼虎"
        case clam = "真格蛤蜊"
    }
}

#Preview {
    StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "VnNTdGFnZS0xNg==", stats: .init(winRateCl: 0.778, winRateLf: 0.678, winRateTw: 0.829, winRateGl: 0.231, winRateAr: 0.456)),sortedBy: .constant(.time))
        .frame(width: 150*2,height: 200*2)
        .fixSafeareaBackground()
}
