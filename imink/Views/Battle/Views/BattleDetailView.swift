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
                            .padding(.bottom, 10)

                    }else{
                        LoadingView(size: 100)
                    }
                }
                Spacer()
            }
            .padding(.horizontal,8)
            .clearFloatingBars()
        }
        .scrollIndicators(.hidden)
        .containerRelativeFrame(.horizontal)
        .frame(maxWidth: .infinity)
        .fixSafeareaBackground()
        .ignoresSafeArea(edges: .vertical)
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
                    if rule == .triColor{
                        FestIcon(colors: battle.getColors())
                            //                            .resizable()
                            .frame(width: 30, height: 30)
                            .mask(                                 // 再把整体裁小一圈
                                GeometryReader { geo in
                                    let w = geo.size.width  * 0.75
                                    let h = geo.size.height * 0.75
                                    Rectangle()
                                        .frame(width: w, height: h)
                                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                }
                            )
                    }else{
                        mode.icon
                            .resizable()
                            .frame(width: 30, height: 30)
                            .padding(.top, -0.5)
                            .padding(.bottom, -1.5)
                    }
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
                        BattleWaveOverlay(crt: battle.getColorRatioText()),
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




    var winTeamView:some View{
        VStack{
            ForEach(0..<winTeam.count,id: \.self){ index in
                VStack(alignment: .leading, spacing: 3) {
                    Text("VICTORY")
                        .font(.splatoonFont1(size: 12))
                        .padding(.leading,10)
                        .foregroundStyle(winTeam[index].color.toColor())

                    BattleTeamList(
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

                    BattleTeamList(
                        team: loseTeam[index],
                        activePlayer: $activePlayer,
                        showPlayerSkill:$showPlayerSkill,
                        hoveredMember: $hoveredMember
                    )
                }
            }
        }
    }


}

    //#Preview {
    //    BattleDetailView()
    //}


