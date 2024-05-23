import SwiftUI

struct HomePage: View {
    
    @StateObject var viewModel: HomeViewModel

    @State private var vdChartViewHeight: CGFloat = 0
    @State private var vdChartLastBlockWidth: CGFloat = 0

    @State private var mode: GameMode = .regular

    var body: some View {
        VStack{
            VDGridView(data: viewModel.last500Coop, height: $vdChartViewHeight, lastBlockWidth: $vdChartLastBlockWidth)
                .frame(height: vdChartViewHeight)
//            Picker("mode",selection: $mode){
//                ForEach(GameMode.allCases){ mode in
////                    mode.image
////                        .resizable()
////                        .scaledToFit()
////                        .tag(mode)
//                    Text("\(mode.name)")
//                        .tag(mode)
//
//                }
//            }
//            .pickerStyle(SegmentedPickerStyle())
//            .frame(width: 270)
            Text("Total Coop \(viewModel.totalCoop)")
            Text("Total Battle \(viewModel.totalBattle)")
        }
    }
}

//#Preview {
//    HomePage()
//}
