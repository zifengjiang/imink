import SwiftUI
import SplatDatabase

struct BattleWaveOverlay: View {
    let crt: ([Color?], [Double?], [String?])

    /// 把三队颜色/比例整理成从左到右的液面分段。
    private var segments: [InkWaterBar.Segment] {
        var result: [InkWaterBar.Segment] = []
        for index in 0..<3 {
            guard
                let color = (crt.0[safe: index] ?? nil),
                let ratio = (crt.1[safe: index] ?? nil),
                ratio > 0
            else { continue }
            result.append(.init(color: color, ratio: ratio))
        }
        // 单色时补一个占位，保证液面铺满
        return result
    }

    var body: some View {
        InkWaterBar(segments: segments)
            // 先定高：GeometryReader 会吃掉父级给的大尺寸，必须先收成 30pt
            .frame(height: 30)
            .overlay(
                Text((crt.2[safe: 0] ?? nil) ?? "")
                    .font(.splatoonFont1(size: 18))
                    .foregroundStyle(.white)
                    .padding(.leading, 10),
                alignment: .leading
            )
            .overlay(
                Text((crt.2[safe: 2] ?? nil) ?? "")
                    .font(.splatoonFont1(size: 18))
                    .foregroundStyle(.white)
                    .padding(.trailing, 10),
                alignment: .trailing
            )
            .overlay(alignment: .center) {
                if let middleText = (crt.2[safe: 1] ?? nil), !middleText.isEmpty {
                    Text(middleText)
                        .font(.splatoonFont1(size: 18))
                        .foregroundStyle(.white)
                }
            }
            .background(.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 50.0))
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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
