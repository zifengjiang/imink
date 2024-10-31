import SwiftUI
import SplatDatabase

struct BattleDetailView: View {
    @State var phase:Double = 0
    @StateObject var viewModel: BattleDetailViewModel

    @State private var myselfPosition:CGFloat = 0
    @State private var hidePlayerNames: Bool = false
    @State private var showPlayerSkill: Bool = false
    @State private var activePlayer: Player? = nil
    @State private var activePlayerVictory: Bool = false
    @State private var hoveredMember: Bool = false


    init(id:Int64) {
        _viewModel = StateObject(wrappedValue: BattleDetailViewModel(id: id))
    }

    var winTeam:[VsTeam]{
        viewModel.battle?.teams.filter{$0.judgement == "WIN" || $0.order == 1} ?? []
    }

    var loseTeam:[VsTeam]{
        viewModel.battle?.teams.filter{$0.judgement == "LOSE"} ?? []
    }

    var body: some View {
        ScrollView{
            HStack {
                Spacer()
                VStack(spacing:20){
                    if viewModel.initialized{
                        cardView
                            .padding(.top,10)
                        winTeamView
                        loseTeamView

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
        .modifier(Popup(isPresented: showPlayerSkill,
                        onDismiss: {
            showPlayerSkill = false
        }, content: {
            BattlePlayerView(player: activePlayer)
        }))
        .onAppear  {
            viewModel.load()
        }
    }
    var cardView:some View{
        VStack(spacing: 0) {
            if let battle = viewModel.battle,let mode = BattleMode(rawValue: battle.mode), let rule = BattleRule(rawValue: battle.rule),let stage = battle.stage{
                HStack{
                    mode.icon
                        .resizable()
                        .frame(width: 30, height: 30)
                        .padding(.top, -0.5)
                        .padding(.bottom, -1.5)
                    Text(rule.name)
                        .font(.splatoonFont(size: 20))
                        .foregroundStyle(mode.color)
                    Spacer()
                    Text(battle.playedTime.toPlayedTimeString(full: true))
                        .font(.splatoonFont(size: 18))
                        .foregroundStyle(.secondary)
                }
                .padding(.all,12)
                Image(stage.name)
                    .resizable()
                    .scaledToFit()
                    .overlay (
                        WaveOverlay(crt: battle.getColorRatioText()),
                        alignment: .bottom
                    )
                    .overlay(
                        Text(battle.judgement == "DEEMED_LOSE" ? "对战未能正常结束" : "")
                            .font(.splatoonFont(size: 18)),
                        alignment: .bottom
                    )

            }
        }
        .textureBackground(texture: .streak, radius: 18)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    struct WaveOverlay:View {
        let crt:([Color?],[Double?],[String?])

        var body: some View {
            WaveBarView(percent:0.1, rightColor: crt.0[2] ?? .accent ,middleColor:crt.0[1], middleRatio:crt.1[1], leftColor: crt.0[0],leftRatio: crt.1[0])
                .overlay(
                    Text(crt.2[0] ?? "")
                        .font(.splatoonFont1(size: 18))
                        .foregroundStyle(.white)
                        .padding(.leading,10)
                    ,
                    alignment: .leading)
                .overlay(
                    Text(crt.2[2] ?? "")
                        .font(.splatoonFont1(size: 18))
                        .foregroundStyle(.white)
                        .padding(.trailing,10)
                    ,
                    alignment: .trailing)
                .background(.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 50.0))
                .frame(height: 30)
                .padding(.horizontal,10)
                .padding(.bottom,10)


        }
    }

    struct DividerViewBuilder<Content: View, Item>: View {
        var items: [Item]
        let content: (Item) -> Content

        init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
            self.items = items
            self.content = content
        }

        var body: some View {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                content(item)
                if index < items.count - 1 {
                    Divider()
                }
            }
        }
    }

    struct TeamList:View {
        let team:VsTeam
        @Binding var activePlayer:Player?
        @Binding var showPlayerSkill: Bool
        @Binding var hoveredMember: Bool
        @State var center:CGPoint?
        @State var height:CGFloat?
        @State private var offset: CGFloat = 0
        var index:Int?{
            team.players.firstIndex(where: {$0.isMyself ?? false})
        }
        var playerCount:Int{
            Int(team.players.count)
        }
        var body: some View {
            VStack(spacing: 5) {
                DividerViewBuilder(items: team.players) { player in
                    PlayerRow(player: player,color: team.color.toColor())
                        .overlay {
                            TouchDownAndTouchUpGestureView {
                                activePlayer = player
                                hoveredMember = true
                            } touchMovedCallBack: { distance in
                                if distance > 10 {
                                    hoveredMember = false
                                }
                            } touchUpCallBack: {
                                if hoveredMember {
                                    withAnimation {
                                        showPlayerSkill = true
                                    }

                                    hoveredMember = false
                                }
                            }
                        }
                }
            }
            .overlay {
                GeometryReader { geometry in
                    Color.clear.onAppear{
                        center = CGPoint(x: geometry.frame(in: .local).minX, y: geometry.frame(in: .local).minY)
                        height = geometry.size.height
                    }
                }
            }
            .padding(.all,10)
            .background(Color.listItemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if let index{
                    var offset:CGFloat{
                        CGFloat(10+(playerCount-(index+1))*2)
                    }
                    Image(.memberArrow)

                        .foregroundStyle(Color.memberArrow)
                        .position(x:center?.x ?? 0,y: (center?.y ?? 0) + (height ?? 0)/CGFloat(Double(playerCount)/Double(index+1))-offset)
                        .offset(x: -self.offset)
                        .onAppear {
                            withAnimation(Animation.linear(duration: 0.55).repeatForever(autoreverses: true)) {
                                self.offset = 7
                            }
                        }
                }
            }

        }
    }

    var winTeamView:some View{
        VStack{
            ForEach(0..<winTeam.count,id: \.self){ index in
                VStack(alignment: .leading, spacing: 3) {
                    Text("VICTORY")
                        .font(.splatoonFont1(size: 12))
                        .padding(.leading,10)
                        .foregroundStyle(winTeam[index].color.toColor())

                    TeamList(
                        team: winTeam[index],
                        activePlayer: $activePlayer,
                        showPlayerSkill:$showPlayerSkill,
                        hoveredMember: $hoveredMember
                    )
                }
            }
        }
    }

    var loseTeamView:some View{
        VStack{
            ForEach(0..<loseTeam.count,id: \.self){ index in
                VStack(alignment: .leading, spacing: 3) {
                    Text("DEFEAT")
                        .font(.splatoonFont1(size: 12))
                        .padding(.leading,10)
                        .foregroundStyle(loseTeam[index].color.toColor())

                    TeamList(
                        team: loseTeam[index],
                        activePlayer: $activePlayer,
                        showPlayerSkill:$showPlayerSkill,
                        hoveredMember: $hoveredMember
                    )
                }
            }
        }
    }

    struct PlayerRow:View {
        let player:Player
        let color:Color
        @StateObject var viewModel = ViewModel()
        var body: some View {
            HStack{
                if let weapon = player._weapon{
                    Image(weapon.mainWeapon.name)
                        .resizable()
                        .scaledToFit()
                        .background(.black.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: .infinity, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4){
                    Text(viewModel.formattedByname ?? player.byname)
                        .font(.splatoonFont(size: 9))
                        .foregroundStyle(.secondary)
                    Text(player.name)
                        .font(.splatoonFont(size: 15))
                }
                Spacer()
                Text("\(player.paint ?? 0)p")
                    .font(.splatoonFont(size: 15))
                kda
                    .padding(.horizontal,5)
                    .padding(.vertical, 3)
                    .background(.listBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .task {
                await viewModel._formatByname(byname: player.byname)
            }
        }

        class ViewModel:ObservableObject{
            @Published var formattedByname: String?

            func _formatByname(byname:String) async{
                let formatted = await formatByname(byname)
                DispatchQueue.main.async {
                    if let adjective = formatted?.adjective, let subjective = formatted?.subject{
                        if let male = formatted?.male{
                            if male, let sub = subjective.localizedFromSplatNet.split(separator: "/").first{
                                self.formattedByname = adjective.localizedFromSplatNet + sub
                            }else{
                                self.formattedByname = adjective.localizedFromSplatNet + subjective.localizedFromSplatNet.split(separator: "/").last!
                            }
                        }else{
                            self.formattedByname = adjective.localizedFromSplatNet + subjective.localizedFromSplatNet
                        }
                    }else{
                        self.formattedByname = byname
                    }
                }
            }
        }

        var kda:some View{
            HStack{
                HStack(alignment: .bottom, spacing: 0){
                    Text("x\(player.kill ?? 0)")
                        .font(.splatoonFont(size: 15))
                    Text("<\(player.assist ?? 0)>")
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text("x\(player.death ?? 0)")
                    .font(.splatoonFont(size: 15))
                VStack(spacing:1){
                    if let weapon = player._weapon{
                        SpecialWeaponImage(imageName: weapon.specialWeapon.name, color: color, size: 12)
//                            .scaledToFit()
//                            .frame(width: 12, height: 12)
                    }
                    Text("x\(player.special ?? 0)")
                        .font(.splatoonFont(size: 12))
                }
            }
        }
    }

}

//#Preview {
//    BattleDetailView()
//}

extension Battle {
    func getColorRatioText()->([Color?],[Double?],[String?]){
        var colors:[Color?] = []
        var ratios:[Double?] = []
        var texts:[String?] = []
        colors.append(teams.first{$0.order == 1}?.color.toColor())
        if let rule = BattleRule(rawValue: rule), rule == .triColor{
            colors.append(teams.first{$0.order == 2}?.color.toColor())
            colors.append(teams.first{$0.order == 3}?.color.toColor())
        }else{
            colors.append(nil)
            colors.append(teams.first{$0.order == 2}?.color.toColor())
        }

        if let rule = BattleRule(rawValue: rule), rule == .triColor || rule == .turfWar{
            ratios.append(teams.first{$0.order == 1}?.paintRatio)
            texts.append("\((teams.first{$0.order == 1}?.paintRatio ?? 0)*100)%")
            if rule == .triColor{
                ratios.append(teams.first{$0.order == 2}?.paintRatio)
                texts.append("\((teams.first{$0.order == 2}?.paintRatio ?? 0)*100)%")
                ratios.append(teams.first{$0.order == 3}?.paintRatio)
                texts.append("\((teams.first{$0.order == 3}?.paintRatio ?? 0)*100)%")
            }else{
                ratios.append(nil)
                texts.append(nil)
                ratios.append(teams.first{$0.order == 2}?.paintRatio)
                texts.append("\((teams.first{$0.order == 2}?.paintRatio ?? 0)*100)%")
            }
        }else if let myTeam = teams.first(where: {$0.order == 1}), let otherTeam = teams.first(where: {$0.order == 2}),let leftScore = myTeam.score,let rightScore = otherTeam.score{
            ratios.append(Double(leftScore)/Double(leftScore+rightScore))
            texts.append("\(leftScore)计数")
            ratios.append(nil)
            texts.append(nil)
            ratios.append(Double(rightScore)/Double(leftScore+rightScore))
            texts.append("\(rightScore)计数")
        }

        while colors.count < 3{
            colors.append(nil)
        }
        while ratios.count < 3{
            ratios.append(nil)
        }
        while texts.count < 3{
            texts.append(nil)
        }
        return (colors, ratios, texts)
    }
}

