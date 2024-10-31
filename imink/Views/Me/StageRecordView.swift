    //
    //  StageRecordView.swift
    //  imink
    //
    //  Created by 姜锋 on 10/29/24.
    //

import SwiftUI
import SplatNet3API

struct StageRecordView: View {
    @StateObject var viewModel = StageRecordViewModel()

    var body: some View {
        NavigationStack{
            ScrollView{
                    //                LazyVStack{
                    //                    ForEach(played,id: \.nameId){ stage in
                    //                        recordRow(stage: stage)
                    //                    }
                    //
                    //                }

                LazyVStack{
                    ForEach(viewModel.played, id: \.nameId){ stage in
                        RecordRowView(stage: stage)
                    }
                }

                VStack(alignment: .leading){
                    Text("未游玩的场地")
                        .font(.splatoonFont(size: 15))

                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                        .padding(.bottom, 5)
                        .padding(.leading, 10)

                    LazyVStack{
                        ForEach(viewModel.notPlayed,id: \.nameId){ stage in
                            RecordRowView(stage: stage)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .fixSafeareaBackground()
        .task {
            await viewModel.fetchStageRecords()
        }
    }

    @ViewBuilder
    func recordRow(stage:StageRecord) -> some View{

    }

    struct RecordRowView:View {
        let stage:StageRecord
        var body: some View {
            HStack{
                VStack{
                    Image(stage.name)
                        .resizable()
                        .aspectRatio(640 / 360, contentMode: .fill)
                        .frame(width: 640 / 6, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                    Text(stage.nameId.localizedFromSplatNet)
                        .font(.splatoonFont(size: 12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)
                }


                HStack{
                    VStack(spacing:5){
                        HStack{
                            Text("占地对战")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                            Text(stage.stats?.winRateTw == nil ? "-": "\(stage.stats?.winRateTw ?? 0, specifier: "%.1f")%")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        HStack{
                            Text("真格区域")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                            Text(stage.stats?.winRateAr == nil ? "-": "\(stage.stats?.winRateAr ?? 0, specifier: "%.1f")%")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        HStack{
                            Text("真格塔楼")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                            Text(stage.stats?.winRateAr == nil ? "-": "\(stage.stats?.winRateAr ?? 0, specifier: "%.1f")%")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        HStack{
                            Text("真格鱼虎")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                            Text(stage.stats?.winRateAr == nil ? "-": "\(stage.stats?.winRateAr ?? 0, specifier: "%.1f")%")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        HStack{
                            Text("真格蛤蜊")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                            Text(stage.stats?.winRateAr == nil ? "-": "\(stage.stats?.winRateAr ?? 0, specifier: "%.1f")%")
                                .font(.splatoonFont(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 10.5)
            .padding(.bottom, 7)
            .padding([.leading, .trailing], 8)
            .background(Color(.listItemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(height: 100)
                //            .padding([.leading, .trailing])

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
                $0.stats == nil
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
        stageRecords.filter{$0.stats != nil}
    }

    func fetchStageRecords() async {
        let records = await SN3Client.shared.fetchStageRecord()
        DispatchQueue.main.async {
            self.stageRecords = records
        }
    }

    func sortBy(_ by: SortedBy) {
        sortedBy = by
        sort()
    }

    func sort() {
        let sorted = stageRecords.sorted { (lhs, rhs) -> Bool in
            switch self.sortedBy {
            case .time:
                return lhs.stats?.lastPlayedTime ?? Date(timeIntervalSince1970: 0) > rhs.stats?.lastPlayedTime ?? Date(timeIntervalSince1970: 0)
            case .area:
                return lhs.stats?.winRateAr ?? 0 > rhs.stats?.winRateAr ?? 0
            case .turf:
                return lhs.stats?.winRateTw ?? 0 > rhs.stats?.winRateTw ?? 0
            case .tower:
                return lhs.stats?.winRateLf ?? 0 > rhs.stats?.winRateLf ?? 0
            case .rain:
                return lhs.stats?.winRateGl ?? 0 > rhs.stats?.winRateGl ?? 0
            case .clam:
                return lhs.stats?.winRateCl ?? 0 > rhs.stats?.winRateCl ?? 0
            }
        }

        withAnimation {
            stageRecords = sorted
        }
    }

    enum SortedBy {
        case time
        case area
        case turf
        case tower
        case rain
        case clam
    }
}

#Preview {
    NavigationStack{
        ScrollView{
            LazyVGrid(columns: [GridItem(.flexible(),spacing: 0),
                                GridItem(.flexible())],spacing: 5){
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
                StageRecordView.RecordRowView(stage: .init(name: "Vss_Carousel", nameId: "reef", stats: nil))
            }
        }
        .fixSafeareaBackground()
    }

}
