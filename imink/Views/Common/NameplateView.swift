import SwiftUI
import SplatDatabase

class NameplateViewModel:ObservableObject{
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

struct NameplateView: View {
    let name:String
    let background: String
    let byname:String
    let textColor:Color
    let badges: [String?]
    let nameId: String
    @StateObject var viewModel = NameplateViewModel()

    init(status: CoopPlayerStatus){
        name = status.name
        background = status._nameplate?.background ?? ""
        byname = status.byname
        textColor = status._nameplate?.textColor ?? .white
        badges = status._nameplate?.badges ?? []
        nameId = status.nameId
    }
    
    init(result: CoopPlayerResult) {
        name = result.player!.name
        background = result.player!._nameplate!.background
        byname = result.player!.byname
        textColor = result.player!._nameplate!.textColor
        badges = result.player!._nameplate!.badges
        nameId = result.player!.nameId
    }

    var body: some View {
        GeometryReader { geometry in
            let geometryHeight = geometry.size.height
            let geometryWidth = geometry.size.width

            ZStack(alignment: .topLeading) {

                    Image(background)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometryWidth, height: geometryHeight)
                        .clipped()
                        .cornerRadius(geometryWidth*0.02)


                if let byname = viewModel.formattedByname{
                    Text(byname)
                        .font(.splatoonFont(size: geometryWidth * 12/284))
                        .foregroundColor(textColor)
                        .padding(.top, geometryWidth * 5/284)
                        .padding(.leading, geometryWidth * 10/284)
                }else{
                    Text(byname)
                        .font(.splatoonFont(size: geometryWidth * 12/284))
                        .foregroundColor(textColor)
                        .padding(.top, geometryWidth * 5/284)
                        .padding(.leading, geometryWidth * 10/284)
                }


                Text(name)
                    .font(.splatoonFont1(size: geometryWidth * 26/284))
                    .foregroundColor(textColor)
                    .position(x: geometryWidth / 2, y: geometryHeight / 2)

                if badges.count != 0{

                    VStack {
                        Spacer()
                        HStack(spacing:geometryWidth*2/284) {
                            Spacer()

                                ForEach(badges.indices , id: \.self) { index in
                                    if let badge = badges[index] {
                                        Image(badge)
                                            .resizable()
                                            .scaledToFit()
                                            .padding([.trailing,.bottom],1/284)
                                            .frame(width: geometryHeight * 0.345, height: geometryHeight * 0.345)

                                    }else{
                                        Color.clear
                                            .padding([.trailing,.bottom],1/284)
                                            .frame(width: geometryHeight * 0.345, height: geometryHeight * 0.345)
                                    }
                                }

                        }
                    }

                }


                VStack {
                    Spacer()
                    HStack {
                        Text("#\(nameId)")
                            .font(.splatoonFont(size: geometryWidth*10/284))
                            .foregroundColor(textColor)
                            .padding(.leading, geometryWidth * 10/284)
                            .padding(.bottom, geometryWidth * 5/284)

                        Spacer()
                    }

                }

            }
        }
        .aspectRatio(3.5, contentMode: .fit)
        .frame(minWidth: 50)
        .task {
            await viewModel._formatByname(byname: byname)
        }
    }

}






