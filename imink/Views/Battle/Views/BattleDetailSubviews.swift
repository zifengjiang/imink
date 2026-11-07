import SwiftUI
import SplatDatabase

struct BattleWaveOverlay:View {
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

struct BattleTeamList:View {
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
                BattleDetailPlayerRow(player: player, color: team.color.toColor())
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
//                                    withAnimation {
                                    showPlayerSkill = true
//                                    }

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
                    .animation(
                        Animation.linear(duration: 0.55).repeatForever(autoreverses: true),
                        value: offset
                    )
                    .onAppear {
                        // 由上面的 .animation(_:value:) 驱动来回摆动
                        self.offset = 7
                    }
            }
        }

    }
}

struct BattleDetailPlayerRow:View {
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
