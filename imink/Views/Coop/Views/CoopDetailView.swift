import SwiftUI
import SplatDatabase

struct CoopDetailView: View {

    @State var phase:Double = 0
    @StateObject var viewModel: CoopDetailViewModel
    var id: Int64
    init(id: Int64){
        self.id = id
        _viewModel = StateObject(wrappedValue: CoopDetailViewModel(id: id))
    }

    var dangerRateText:String{
        if let dangerRate = viewModel.coop?.dangerRate{
            if dangerRate >= 3.33{
                return "MAX!!"
            }
            return "\(Int(dangerRate*100))%"
        }
        return ""
    }

    var body: some View {
        ScrollView{
            HStack {
                Spacer()
                VStack(spacing:20){
                    if viewModel.initialized{
                        cardView
                            .padding(.top,10)
                        waveView
                        memberView
                        enemyView
                    }else{
                        Spacer()
                        Image(.squidLoading)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(phase))
                        Text("Loading...")
                            .font(.splatoonFont(size: 20))
                        Spacer()
                    }
                }
                Spacer()
            }
            .padding(.horizontal,8)
        }
        .frame(maxWidth: .infinity)
        .fixSafeareaBackground()
        .onAppear  {
            print("load Coop \(self.id)")
            viewModel.load()
        }

    }

    var cardView:some View {
        makeCardView()
    }

    var waveView: some View{
        VStack {
            if let coop = viewModel.coop{
                if coop.rule == "TEAM_CONTEST" && viewModel.waveResults.count > 4 {
                    waveResultsView(range: 0..<3)
                    waveResultsView(range: 3..<5)
                } else {
                    waveResultsView(range: viewModel.waveResults.indices)
                }
            }
        }
    }

    var memberView: some View {
        VStack(spacing: 0){
            ForEach(viewModel.playerResults.indices, id: \.self){i in
                if i != 0{
                    Divider()
                }
                MemberView(result: viewModel.playerResults[i])
            }
        }
        .padding(.all,10)
        .textureBackground(texture: .bubble, radius: 18)
    }

    var enemyView: some View {
        VStack{
            ForEach(viewModel.enemyResults.indices, id: \.self){ i in
                if i != 0{
                    Divider()
                }
                makeEnemyView(result: viewModel.enemyResults[i])
            }
        }
        .padding(.all,10)
        .textureBackground(texture: .bubble, radius: 18)
    }
}


extension CoopDetailView {
    func makeCardView() -> some View {
        VStack(alignment: .leading, spacing: 4){
            if let coop = viewModel.coop{
                HStack {
                    VStack(alignment: .leading,spacing: 0) {
                        HStack(spacing: 10) {
                            CoopRule(rawValue: coop.rule)?.icon

                            Text(coop.playedTime.toPlayedTimeString(full: true))
                                .font(.splatoonFont1(size: 15))
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                        }
                        .padding(.bottom, 7)
                        
                        if let stageImage = coop.stageImage{
                            Image(stageImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    VStack {
                        Text(coop.clear ? "Clear!!" : "Failure")
                            .font(.splatoonFont1(size: 30))
                            .foregroundStyle(coop.clear ? Color.waveClear : Color.waveDefeat)
                        Spacer()
                        VStack{
                            VStack(spacing:5) {
                                HStack {
                                    Text("your_points")
                                        .font(.splatoonFont(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.3)
                                    Spacer()
                                    Text("\(coop.jobPoint ?? 0)p")
                                        .font(.splatoonFont(size: 20))
                                }
                                GeometryReader { geo in
                                    Path { path in
                                        path.move(to: .init(x: 0, y: 0))
                                        path.addLine(to: .init(x: geo.size.width, y: 0))
                                    }
                                    .stroke(style: StrokeStyle(lineWidth: 1))
                                    .foregroundColor(Color.waveDefeat)
                                }
                                .frame(height: 1)
                                HStack(spacing:4){
                                    VStack(spacing:4){
                                        Text("\(coop.jobScore ?? 0)")
                                        Text("job_score")
                                            .font(.splatoonFont(size: 8))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.3)
                                    }
                                    Text("x")
                                        .font(.splatoonFont(size: 12))
                                    VStack(spacing:4){
                                        Text("\(coop.jobRate ?? 0,places: 2)")
                                        Text("pay_grade")
                                            .font(.splatoonFont(size: 8))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.3)
                                    }
                                    Text("+")
                                    VStack(spacing:4){
                                        Text("\(coop.jobBonus ?? 0)")
                                        Text("clear_bonus")
                                            .font(.splatoonFont(size: 8))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.3)
                                    }
                                }
                                .font(.splatoonFont(size: 16))
                            }
                            .padding([.leading, .trailing], 3)
                            .padding([.top, .bottom], 3)
                            .background(Color(.sRGB, white: 201 / 255.0, opacity: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .frame(width:135)
                            Spacer()
                            if coop.rule == CoopRule.TEAM_CONTEST.rawValue{
                                EmptyView()
                                    .padding([.leading, .trailing], 3)
                                    .padding([.top, .bottom], 3)
                                    .background(Color(.sRGB, white: 201 / 255.0, opacity: 0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    .frame(width:135)
                            }else{
                                VStack(alignment: .leading,spacing: 2){
                                    if let gradeName = coop.gradeName, let gradePoint = coop.afterGradePoint{
                                        Text("\(gradeName.localizedFromSplatNet) \(gradePoint)")
                                            .font(.splatoonFont(size: 12))
                                            .foregroundStyle(Color.waveClear)
                                        ProgressBar(fillPercentage: gradePoint >= 100 ? 1 : Double(gradePoint)/Double(100))
                                            .padding([.bottom,.top],2)
                                    }

                                    HStack{
                                        var scaleImage:[Image]{[Image(.urocoIcon00),Image(.urocoIcon01),Image(.urocoIcon02)]}
                                        var scales:[String] {
                                            if coop.goldScale != nil {
                                                return ["\(coop.goldScale ?? 0)","\(coop.silverScale ?? 0)","\(coop.bronzeScale ?? 0)"]
                                            }
                                            return ["-","-","-"]
                                        }
                                        ForEach(0..<3,id: \.self) { i in
                                            HStack(spacing:0){
                                                scaleImage[i]
                                                    .resizable()
                                                    .frame(width: 18, height: 18)
                                                Text(scales[i])
                                                    .font(.splatoonFont(size: 12))
                                            }
                                            if i != 2{
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                                .padding([.leading, .trailing], 3)
                                .padding([.top, .bottom], 3)
                                .background(Color(.sRGB, white: 201 / 255.0, opacity: 0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .frame(width:135)
                            }
                        }
                    }
                }


                HStack {
                    if let stageName = coop.stageName{
                        Text(stageName.localizedFromSplatNet)
                            .font(.splatoonFont(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 3){
                        Image(.golden)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(coop.egg)")
                            .font(.splatoonFont(size: 15))
                    }


                    HStack(spacing: 3){
                        Image(.egg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(coop.powerEgg)")
                            .font(.splatoonFont(size: 15))
                    }
                }

                GeometryReader { geo in
                    Path { path in
                        path.move(to: .init(x: 0, y: 0))
                        path.addLine(to: .init(x: geo.size.width, y: 0))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3.5, 3.5]))
                    .foregroundColor(Color.init(.sRGB, white: 0.4, opacity: 0.36))
                }
                .frame(height: 1)

                HStack{
                    if let suppliedWeapons = coop.suppliedWeapons{
                        ForEach(suppliedWeapons.indices,id: \.self){ i in
                            Image(suppliedWeapons[i])
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }
                    }
                    Spacer()
                    Text(dangerRateText)
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

        }
        .overlay(alignment: .topTrailing) {
            if let smellMeter = viewModel.coop?.smellMeter, let bossName = viewModel.coop?.bossName{
                SineWaveShape(percent: 1-Double(smellMeter)*0.2, strength: 1.2, frequency: 12, phase: self.phase, totalWidth: 60)
                    .fill(Color.salmonRunTheme)
                    .animation(Animation.linear(duration: 3).repeatForever(autoreverses: false), value: self.phase)
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            phase = .pi * 2
                        }
                    }
                    .frame(width: 60,height: 60)
                    .background {
                        Color.battleDetailStreakForeground
                    }
                    .mask {
                        Image(bossName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60,height: 60)
                            .colorMultiply(.black)
                    }

                    .offset(x:20,y:-40)
            }
        }
        .padding([.leading, .trailing], 12)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .textureBackground(texture: .bubble, radius: 18)
    }


        struct MemberView:View {
            let result: CoopPlayerResult
            var body: some View {
                HStack{
                    VStack(alignment: .leading, spacing:5){
                        Text(result.player!.name)
                            .font(.splatoonFont(size: 15))
                        Text("\("boss_salmonids".localized) x\(result.defeatEnemyCount)")
                            .font(.splatoonFont(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing,spacing: 0){
                        HStack{
                            HStack{
                                if let weapons = result.weapons{
                                    ForEach(weapons.indices, id:\.self){i in
                                        Image(weapons[i])
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                            .background(Color(.sRGB, white: 121 / 255.0, opacity: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            if let specialWeaponName = result.specialWeaponName{
                                SpecialWeaponImage(imageName: specialWeaponName,size: 15)
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(height: 24)

                        HStack{
                            HStack(spacing:2){
                                Image(.golden)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 12)
                                Text("\(result.goldenDeliverCount)").font(.splatoonFont(size: 12))+Text("+\(result.goldenAssistCount)").font(.splatoonFont(size: 9))
                            }

                            Group{
                                HStack(spacing:2){
                                    Image(.egg)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 12)
                                    Text("\(result.deliverCount)")
                                }

                                HStack(spacing:2){
                                    Image(result.player!.species ? .rescueINKLING : .rescueOCTOLING)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 12)
                                    Text("\(result.rescueCount)")
                                }

                                HStack(spacing:2){
                                    Image(result.player!.species ? .rescuedINKLING : .rescuedOCTOLING)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 12)
                                    Text("\(result.rescuedCount)")
                                }
                            }
                            .font(.splatoonFont(size: 12))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                    }
                }
                .frame(height: 45)
                .contextMenu {
                    Button {

                    } label: {
                        Text("ok")
                    }

                } preview: {
                    VStack{
                        NameplateView(result: result)
                        Image(result.player!.uniformName!)
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(width: 300, height: 300)
                    .padding()
                    .textureBackground(texture: .bubble, radius: 18)
                }
            }
        }




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

    private func waveResultsView(range: Range<Int>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(range, id: \.self) { waveIndex in
                let waveResult = viewModel.waveResults[waveIndex]
                CoopDetailWaveResultView(result: waveResult, pass: isWavePassed(waveResult), bossName: viewModel.coop?.bossName)
                    .rotationEffect(.degrees(-2))
            }
        }
    }
}

struct ProgressBar: View {
    var fillPercentage: CGFloat  // 0.0 到 1.0 之间

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle() // 背景条
                    .foregroundColor(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                Rectangle() // 填充条
                    .frame(width: geometry.size.width * fillPercentage)
                    .foregroundColor(Color.waveDefeat)
                    .cornerRadius(10)
            }
        }
        .frame(height: 8) // 指定高度
    }
}


#Preview {
    CoopDetailView(id: 0)
}
