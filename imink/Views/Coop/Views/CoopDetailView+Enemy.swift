import SwiftUI
import SplatDatabase

extension CoopDetailView {
    func makeEnemyView(result:CoopEnemyResult) -> some View{
        HStack{
            if let enemyImage = result.enemyImage{
                Image(enemyImage)
                    .resizable()
                    .scaledToFit()
            }
            if let enemyName = result.enemyName{
                Text(enemyName.localizedFromSplatNet)
                    .font(.splatoonFont(size: 15))
            }
            Spacer()
            Group {
                Text("\(result.teamDefeatCount)").font(.splatoonFont(size: 15)) + Text(result.defeatCount == 0 ? "" : "(\(result.defeatCount))").font(.splatoonFont(size: 12))
                Text("/")
                    .font(.splatoonFont(size: 16))
                Text("\("appearances_number".localized)x").font(.splatoonFont(size: 12)) + Text("\(result.popCount)").font(.splatoonFont(size: 15))
            }
            .foregroundStyle(result.popCount == result.teamDefeatCount ? Color.waveClear : Color.coopEnemyNotAllClear)

        }
        .frame(height: 40)
    }

    func waveResultsView(range: Range<Int>) -> some View {
        HStack(alignment: .top, spacing: 7) {
            ForEach(range, id: \.self) { waveIndex in
                let waveResult = viewModel.waveResults[waveIndex]
                CoopDetailWaveResultView(result: waveResult, pass: isWavePassed(waveResult), bossName: viewModel.coop?.bossName)
                    .rotationEffect(.degrees(-2))
            }
        }
    }
}



#Preview {
    CoopDetailView(id: 0, navigationPath: .constant(NavigationPath()))
}
