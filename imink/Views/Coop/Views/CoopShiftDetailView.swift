import SwiftUI

struct CoopShiftDetailView: View {
    @StateObject var viewModel: CoopShiftDetailViewModel
    var id: Int
    init(id: Int){
        self.id = id
        _viewModel = StateObject(wrappedValue: CoopShiftDetailViewModel(id: id))
    }

    var body: some View {
        ScrollView{
            HStack {
                Spacer()
                VStack(spacing:20){
                    if viewModel.initialized{
                        cardView
                    }else{
                        Spacer()
                        Image(.squidLoading)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)

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
            print("load Shift \(self.id)")
            viewModel.load()
        }
    }

    var timeSpanText:String? {
        if let coopGroupStatus = viewModel.coopGroupStatus{
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy MM/dd HH:mm"
            return "\(formatter.string(from: coopGroupStatus.startTime)) - \(formatter.string(from: coopGroupStatus.endTime))"
        }
        return nil
    }

    var cardView:some View{

        VStack{
            if let coopGroupStatus = viewModel.coopGroupStatus{
                VStack{
                    HStack{
                        VStack(spacing:0){
                            HStack(spacing:10) {
                                CoopRule(rawValue: coopGroupStatus.rule)?.icon
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30)

                                Text(timeSpanText!)
                                    .font(.splatoonFont(size: 15))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.3)
                                    .foregroundStyle(Color.orange)


                            }
                            if let stageImage = coopGroupStatus.stageImage, let stageName = coopGroupStatus.stageName{
                                Image(stageImage)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Text(stageName.localizedFromSplatNet)
                                    .font(.splatoonFont(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack{
                            Text("Summary")
                                .font(.splatoonFont(size: 30))
                                .foregroundStyle(Color.orange)
                            if let highestScore = coopGroupStatus.highestScore{
                                Text("最高分\(highestScore)")
                                    .font(.splatoonFont(size: 18))
                                    .foregroundStyle(Color.orange)
                            }
                            HStack{
                                Image(.golden)
                                Text("\(coopGroupStatus.highestEgg)")
                                    .font(.splatoonFont(size: 18))
                                    .foregroundStyle(Color.green)
                            }

                            HStack{
                                var
                            scaleImage:[Image]{[Image(.scale1),Image(.scale2),Image(.scale3)]}
                                var scales:[Int]{
                                    [coopGroupStatus.bronzeScale, coopGroupStatus.silverScale, coopGroupStatus.goldScale]
                                }
                                ForEach(0..<3,id: \.self) { i in
                                    HStack(spacing:0){
                                        scaleImage[i]
                                            .resizable()
                                            .frame(width: 18, height: 18)
                                        Text("\(scales[i])")
                                            .font(.splatoonFont(size: 12))
                                    }
                                }
                            }

                            VStack(alignment: .center){
                                HStack{
                                    Text("Clear:\(coopGroupStatus.clear)")
                                        .foregroundStyle(.waveClear)
                                    Text("Failure:\(coopGroupStatus.failure)")
                                        .foregroundStyle(.waveDefeat)
                                }
                                if coopGroupStatus.disconnect > 0{
                                    Text("Disconnect:\(coopGroupStatus.disconnect)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.splatoonFont(size: 13))
                            Spacer()
                        }
                    }

                    Divider()

                    HStack{
                        Text("发放武器")
                            .font(.splatoonFont(size: 15))
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack{
                            if let suppliedWeapons = coopGroupStatus.suppliedWeapons {
                                ForEach(suppliedWeapons.indices, id: \.self){ i in
                                    VStack{
                                        Image(suppliedWeapons[i])
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 30, height: 30)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding([.leading, .trailing], 12)
                .padding(.top, 9)
                .padding(.bottom, 8)
                .textureBackground(texture: .bubble, radius: 18)

                VStack { }
                    .frame(maxWidth: .infinity, minHeight: 19, maxHeight: 19)
                    .overlay(
                        GrayscaleTextureView(
                            texture: .bubble,
                            foregroundColor: Color.battleDetailStreakForeground,
                            backgroundColor: Color.listItemBackground
                        )
                        .frame(height: 100)
                        .offset(y: -78)
                        .mask(
                            VStack {
                                HStack {
                                    Spacer()
                                    Image("JobShiftCardTail")
                                        .resizable()
                                        .frame(width: 33, height: 19)
                                }
                                Spacer()
                            }
                                .padding(.trailing, 24)
                        ),
                        alignment: .topLeading
                    )
                    .overlay {
                        HStack(spacing:0){
                            Text("\(coopGroupStatus.count)场打工")
                                .font(.splatoonFont(size: 12))
                                //                        if stats.count != details.count{
                                //                            Text("<\(details.count-stats.count)场掉线>")
                                //                                .inkFont(.font1, size: 10, relativeTo: .body)
                                //                                .foregroundStyle(Color.waveDefeat)
                                //                        }
                        }
                        .foregroundStyle(Color.green)
                        .offset(y:2)
                    }
                    .offset(y: -8)
            }
        }
    }
}

    //#Preview {
    //    CoopShiftDetailView()
    //}
