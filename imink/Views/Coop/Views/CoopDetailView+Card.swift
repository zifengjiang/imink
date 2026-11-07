import SwiftUI
import SplatDatabase

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
                            .offset(y:10)
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
                        // 交给上面的 .animation(_:value:) 驱动循环。
                        // 不能用 withAnimation(.repeatForever)：它会开启一个永不结束的
                        // 动画事务，同期渲染的工具栏等兄弟视图会不断继承该动画而反复闪烁。
                        phase = .pi * 2
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

                    .offset(x:20,y:-30)
            }
        }
        .padding([.leading, .trailing], 12)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .textureBackground(texture: .bubble, radius: 18)
    }
}
