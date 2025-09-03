import SwiftUI

struct FestIcon: View {
    var ratio = 1.0
    var color1:Color = .spGreenLime
    var color2:Color = .spPurple
    var color3:Color = .spYellow

    init(colors:[Color?]) {
        if colors.count > 0{
            color1 = colors[0] ?? .spGreenLime
        }
        if colors.count > 1{
            color2 = colors[1] ?? .spPurple
        }
        if colors.count > 2{
            color3 = colors[2] ?? .spYellow
        }
    }

    init(color1: Color = .spGreenLime, color2: Color = .spPurple, color3: Color = .spYellow, ratio: Double = 1.0) {
        self.color1 = color1
        self.color2 = color2
        self.color3 = color3
        self.ratio = ratio
    }
    var body: some View {
        GeometryReader { geo in
            Canvas{ context, size in
                context.translateBy(x: geo.size.width*90/350, y: geo.size.width*130/350)
                context.fill(path3(in: CGRect(x: 0, y: 0, width: size.width*ratio, height: size.height*ratio)), with: .color(color3))
                context.fill(path33(in: CGRect(x: 0, y: 0, width: size.width*ratio, height: size.height*ratio)), with: .color(color3))
                context.translateBy(x: geo.size.width*0.2/350, y: -geo.size.width*130/350)
                context.fill(path1(in: CGRect(x: 0, y: 0, width: size.width*ratio, height: size.height*ratio)), with: .color(color1))
                context.fill(path11(in: CGRect(x: 0, y: 0, width: size.width*ratio, height: size.height*ratio)), with: .color(color1))
                context.translateBy(x: -geo.size.width*102/350, y: geo.size.width*59.5/350)
                context.fill(path2(in: CGRect(x: 0, y: 0, width: size.width*ratio, height: size.height*ratio)), with: .color(color2))
                context.translateBy(x: geo.size.width*10/350, y: geo.size.width*15/350)
                context.fill(path22(in: CGRect(x: 0, y: 0, width: size.width*ratio, height: size.height*ratio)), with: .color(color2))
            }
//            .frame(width: geo.size.width , height: geo.size.width)
        }
    }

    func path2(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height

        path.move(to: CGPoint(x: 0.34792*width, y: 0.00573*height))
        path.addLine(to: CGPoint(x: 0.38496*width, y: 0.07075*height))
        path.addCurve(to: CGPoint(x: 0.23758*width, y: 0.32957*height), control1: CGPoint(x: 0.29685*width, y: 0.12242*height), control2: CGPoint(x: 0.23758*width, y: 0.21898*height))
        path.addCurve(to: CGPoint(x: 0.38497*width, y: 0.5884*height), control1: CGPoint(x: 0.23758*width, y: 0.44017*height), control2: CGPoint(x: 0.29686*width, y: 0.53673*height))
        path.addLine(to: CGPoint(x: 0.34792*width, y: 0.65341*height))
        path.addCurve(to: CGPoint(x: 0.16347*width, y: 0.32957*height), control1: CGPoint(x: 0.23378*width, y: 0.58661*height), control2: CGPoint(x: 0.16347*width, y: 0.46316*height))
        path.addCurve(to: CGPoint(x: 0.34792*width, y: 0.00573*height), control1: CGPoint(x: 0.16347*width, y: 0.19598*height), control2: CGPoint(x: 0.23378*width, y: 0.07254*height))
        path.closeSubpath()

        return path
    }

    func path22(in rect: CGRect) -> Path{
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.41927*width, y: 0.17756*height))
        path.addLine(to: CGPoint(x: 0.47267*width, y: 0.20446*height))
        path.addLine(to: CGPoint(x: 0.47358*width, y: 0.20222*height))
        path.addCurve(to: CGPoint(x: 0.45129*width, y: 0.14461*height), control1: CGPoint(x: 0.45765*width, y: 0.17746*height), control2: CGPoint(x: 0.45129*width, y: 0.14461*height))
        path.addLine(to: CGPoint(x: 0.42595*width, y: 0.12716*height))
        path.addLine(to: CGPoint(x: 0.37543*width, y: 0.09236*height))
        path.addCurve(to: CGPoint(x: 0.36363*width, y: 0.16742*height), control1: CGPoint(x: 0.35827*width, y: 0.12521*height), control2: CGPoint(x: 0.36363*width, y: 0.16742*height))
        path.addCurve(to: CGPoint(x: 0.41761*width, y: 0.195*height), control1: CGPoint(x: 0.38212*width, y: 0.17122*height), control2: CGPoint(x: 0.41101*width, y: 0.19052*height))
        path.addLine(to: CGPoint(x: 0.41819*width, y: 0.19442*height))
        path.addCurve(to: CGPoint(x: 0.4073*width, y: 0.15036*height), control1: CGPoint(x: 0.40919*width, y: 0.17531*height), control2: CGPoint(x: 0.4073*width, y: 0.15036*height))
        path.addLine(to: CGPoint(x: 0.41423*width, y: 0.15377*height))
        path.addCurve(to: CGPoint(x: 0.41918*width, y: 0.17756*height), control1: CGPoint(x: 0.41365*width, y: 0.16245*height), control2: CGPoint(x: 0.41918*width, y: 0.17756*height))
        path.addLine(to: CGPoint(x: 0.41927*width, y: 0.17756*height))
        path.closeSubpath()

        path.move(to: CGPoint(x: 0.48198*width, y: 0.31541*height))
        path.addLine(to: CGPoint(x: 0.47616*width, y: 0.31524*height))
        path.addLine(to: CGPoint(x: 0.47652*width, y: 0.24448*height))
        path.addCurve(to: CGPoint(x: 0.40382*width, y: 0.19148*height), control1: CGPoint(x: 0.46099*width, y: 0.22583*height), control2: CGPoint(x: 0.43842*width, y: 0.20906*height))
        path.addCurve(to: CGPoint(x: 0.30532*width, y: 0.16709*height), control1: CGPoint(x: 0.36784*width, y: 0.17319*height), control2: CGPoint(x: 0.33316*width, y: 0.16709*height))
        path.addCurve(to: CGPoint(x: 0.25491*width, y: 0.17525*height), control1: CGPoint(x: 0.28358*width, y: 0.16709*height), control2: CGPoint(x: 0.26601*width, y: 0.17077*height))
        path.addCurve(to: CGPoint(x: 0.2106*width, y: 0.30304*height), control1: CGPoint(x: 0.22845*width, y: 0.18592*height), control2: CGPoint(x: 0.18516*width, y: 0.22081*height))
        path.addCurve(to: CGPoint(x: 0.30384*width, y: 0.40374*height), control1: CGPoint(x: 0.23585*width, y: 0.38464*height), control2: CGPoint(x: 0.30282*width, y: 0.40348*height))
        path.addCurve(to: CGPoint(x: 0.36923*width, y: 0.30448*height), control1: CGPoint(x: 0.36044*width, y: 0.37828*height), control2: CGPoint(x: 0.36923*width, y: 0.30448*height))
        path.addLine(to: CGPoint(x: 0.36609*width, y: 0.30241*height))
        path.addCurve(to: CGPoint(x: 0.34241*width, y: 0.32107*height), control1: CGPoint(x: 0.36303*width, y: 0.30941*height), control2: CGPoint(x: 0.35267*width, y: 0.32089*height))
        path.addCurve(to: CGPoint(x: 0.33676*width, y: 0.3199*height), control1: CGPoint(x: 0.34047*width, y: 0.32107*height), control2: CGPoint(x: 0.33862*width, y: 0.32079*height))
        path.addCurve(to: CGPoint(x: 0.32326*width, y: 0.27031*height), control1: CGPoint(x: 0.31873*width, y: 0.31192*height), control2: CGPoint(x: 0.31272*width, y: 0.28232*height))
        path.addCurve(to: CGPoint(x: 0.35267*width, y: 0.25829*height), control1: CGPoint(x: 0.32798*width, y: 0.26484*height), control2: CGPoint(x: 0.33427*width, y: 0.2582*height))
        path.addCurve(to: CGPoint(x: 0.40123*width, y: 0.26753*height), control1: CGPoint(x: 0.36368*width, y: 0.25829*height), control2: CGPoint(x: 0.37913*width, y: 0.26089*height))
        path.addCurve(to: CGPoint(x: 0.4546*width, y: 0.29694*height), control1: CGPoint(x: 0.43*width, y: 0.27623*height), control2: CGPoint(x: 0.44582*width, y: 0.28762*height))
        path.addCurve(to: CGPoint(x: 0.45997*width, y: 0.31891*height), control1: CGPoint(x: 0.46367*width, y: 0.30654*height), control2: CGPoint(x: 0.46728*width, y: 0.31909*height))
        path.addCurve(to: CGPoint(x: 0.44609*width, y: 0.31201*height), control1: CGPoint(x: 0.4571*width, y: 0.31891*height), control2: CGPoint(x: 0.45257*width, y: 0.31685*height))
        path.addCurve(to: CGPoint(x: 0.42834*width, y: 0.28493*height), control1: CGPoint(x: 0.43583*width, y: 0.3043*height), control2: CGPoint(x: 0.43*width, y: 0.29362*height))
        path.addCurve(to: CGPoint(x: 0.38181*width, y: 0.2686*height), control1: CGPoint(x: 0.42094*width, y: 0.27694*height), control2: CGPoint(x: 0.38274*width, y: 0.26878*height))
        path.addCurve(to: CGPoint(x: 0.47967*width, y: 0.37935*height), control1: CGPoint(x: 0.41067*width, y: 0.34877*height), control2: CGPoint(x: 0.45627*width, y: 0.37944*height))
        path.addCurve(to: CGPoint(x: 0.48402*width, y: 0.37891*height), control1: CGPoint(x: 0.48124*width, y: 0.37935*height), control2: CGPoint(x: 0.48272*width, y: 0.37917*height))
        path.addCurve(to: CGPoint(x: 0.50797*width, y: 0.31264*height), control1: CGPoint(x: 0.50326*width, y: 0.37496*height), control2: CGPoint(x: 0.5162*width, y: 0.35245*height))
        path.addCurve(to: CGPoint(x: 0.48198*width, y: 0.31559*height), control1: CGPoint(x: 0.49983*width, y: 0.31461*height), control2: CGPoint(x: 0.49114*width, y: 0.31586*height))
        path.addLine(to: CGPoint(x: 0.48198*width, y: 0.31541*height))
        path.closeSubpath()

        return path
    }

    func path1(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.42494*width, y: 0.17701*height))
        path.addCurve(to: CGPoint(x: 0.60951*width, y: 0.50061*height), control1: CGPoint(x: 0.53915*width, y: 0.24376*height), control2: CGPoint(x: 0.60951*width, y: 0.36712*height))
        path.addLine(to: CGPoint(x: 0.53535*width, y: 0.50061*height))
        path.addCurve(to: CGPoint(x: 0.24037*width, y: 0.20202*height), control1: CGPoint(x: 0.53535*width, y: 0.3357*height), control2: CGPoint(x: 0.40328*width, y: 0.20202*height))
        path.addCurve(to: CGPoint(x: 0.09285*width, y: 0.24198*height), control1: CGPoint(x: 0.18663*width, y: 0.20202*height), control2: CGPoint(x: 0.13624*width, y: 0.21656*height))
        path.addLine(to: CGPoint(x: 0.0558*width, y: 0.17702*height))
        path.addCurve(to: CGPoint(x: 0.42494*width, y: 0.17701*height), control1: CGPoint(x: 0.17001*width, y: 0.11027*height), control2: CGPoint(x: 0.31072*width, y: 0.11027*height))
        path.closeSubpath()
        return path
    }

    func path11(in rect: CGRect) -> Path{
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.38502*width, y: 0.45903*height))
        path.addLine(to: CGPoint(x: 0.33831*width, y: 0.48951*height))
        path.addLine(to: CGPoint(x: 0.33947*width, y: 0.49103*height))
        path.addCurve(to: CGPoint(x: 0.39315*width, y: 0.49549*height), control1: CGPoint(x: 0.36569*width, y: 0.48814*height), control2: CGPoint(x: 0.39315*width, y: 0.49549*height))
        path.addLine(to: CGPoint(x: 0.40965*width, y: 0.48728*height))
        path.addCurve(to: CGPoint(x: 0.44242*width, y: 0.44188*height), control1: CGPoint(x: 0.41687*width, y: 0.46876*height), control2: CGPoint(x: 0.42824*width, y: 0.45499*height))
        path.addCurve(to: CGPoint(x: 0.44906*width, y: 0.43611*height), control1: CGPoint(x: 0.44466*width, y: 0.43986*height), control2: CGPoint(x: 0.44682*width, y: 0.43791*height))
        path.addCurve(to: CGPoint(x: 0.42036*width, y: 0.42076*height), control1: CGPoint(x: 0.43471*width, y: 0.42573*height), control2: CGPoint(x: 0.42036*width, y: 0.42076*height))
        path.addCurve(to: CGPoint(x: 0.37282*width, y: 0.45139*height), control1: CGPoint(x: 0.40824*width, y: 0.43337*height), control2: CGPoint(x: 0.37946*width, y: 0.44808*height))
        path.addLine(to: CGPoint(x: 0.37299*width, y: 0.45211*height))
        path.addCurve(to: CGPoint(x: 0.41098*width, y: 0.46011*height), control1: CGPoint(x: 0.39157*width, y: 0.45233*height), control2: CGPoint(x: 0.41098*width, y: 0.46011*height))
        path.addLine(to: CGPoint(x: 0.40493*width, y: 0.46407*height))
        path.addCurve(to: CGPoint(x: 0.38493*width, y: 0.45903*height), control1: CGPoint(x: 0.39879*width, y: 0.4604*height), control2: CGPoint(x: 0.38493*width, y: 0.45903*height))
        path.addLine(to: CGPoint(x: 0.38502*width, y: 0.45903*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.21992*width, y: 0.46172*height))
        path.addCurve(to: CGPoint(x: 0.23018*width, y: 0.43775*height), control1: CGPoint(x: 0.22211*width, y: 0.45373*height), control2: CGPoint(x: 0.22535*width, y: 0.44548*height))
        path.addLine(to: CGPoint(x: 0.23307*width, y: 0.43314*height))
        path.addLine(to: CGPoint(x: 0.29779*width, y: 0.47058*height))
        path.addCurve(to: CGPoint(x: 0.37628*width, y: 0.43731*height), control1: CGPoint(x: 0.32068*width, y: 0.46685*height), control2: CGPoint(x: 0.34533*width, y: 0.45669*height))
        path.addCurve(to: CGPoint(x: 0.46074*width, y: 0.32404*height), control1: CGPoint(x: 0.43417*width, y: 0.401*height), control2: CGPoint(x: 0.45732*width, y: 0.34958*height))
        path.addCurve(to: CGPoint(x: 0.37348*width, y: 0.22614*height), control1: CGPoint(x: 0.46425*width, y: 0.29729*height), control2: CGPoint(x: 0.45521*width, y: 0.24534*height))
        path.addCurve(to: CGPoint(x: 0.24395*width, y: 0.25324*height), control1: CGPoint(x: 0.29174*width, y: 0.20694*height), control2: CGPoint(x: 0.24395*width, y: 0.25324*height))
        path.addCurve(to: CGPoint(x: 0.29709*width, y: 0.35453*height), control1: CGPoint(x: 0.23868*width, y: 0.3117*height), control2: CGPoint(x: 0.29709*width, y: 0.35453*height))
        path.addLine(to: CGPoint(x: 0.30034*width, y: 0.35297*height))
        path.addCurve(to: CGPoint(x: 0.29937*width, y: 0.32065*height), control1: CGPoint(x: 0.29507*width, y: 0.34602*height), control2: CGPoint(x: 0.28929*width, y: 0.32769*height))
        path.addCurve(to: CGPoint(x: 0.34778*width, y: 0.33368*height), control1: CGPoint(x: 0.31472*width, y: 0.30988*height), control2: CGPoint(x: 0.34252*width, y: 0.31926*height))
        path.addCurve(to: CGPoint(x: 0.31323*width, y: 0.3984*height), control1: CGPoint(x: 0.35155*width, y: 0.34411*height), control2: CGPoint(x: 0.3562*width, y: 0.35914*height))
        path.addCurve(to: CGPoint(x: 0.26298*width, y: 0.42759*height), control1: CGPoint(x: 0.29218*width, y: 0.41759*height), control2: CGPoint(x: 0.27508*width, y: 0.42489*height))
        path.addCurve(to: CGPoint(x: 0.25421*width, y: 0.41343*height), control1: CGPoint(x: 0.2457*width, y: 0.43141*height), control2: CGPoint(x: 0.22869*width, y: 0.42376*height))
        path.addCurve(to: CGPoint(x: 0.2856*width, y: 0.41212*height), control1: CGPoint(x: 0.26561*width, y: 0.40882*height), control2: CGPoint(x: 0.27736*width, y: 0.40926*height))
        path.addCurve(to: CGPoint(x: 0.32156*width, y: 0.38215*height), control1: CGPoint(x: 0.29595*width, y: 0.40995*height), control2: CGPoint(x: 0.32156*width, y: 0.38215*height))
        path.addCurve(to: CGPoint(x: 0.17966*width, y: 0.41195*height), control1: CGPoint(x: 0.23456*width, y: 0.36574*height), control2: CGPoint(x: 0.18615*width, y: 0.39223*height))
        path.addCurve(to: CGPoint(x: 0.22*width, y: 0.4619*height), control1: CGPoint(x: 0.17414*width, y: 0.42889*height), control2: CGPoint(x: 0.1858*width, y: 0.44922*height))
        path.addLine(to: CGPoint(x: 0.21992*width, y: 0.46172*height))
        path.closeSubpath()
        return path
    }

    func path3(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.60951*width, y: 0.12695*height))
        path.addCurve(to: CGPoint(x: 0.42494*width, y: 0.45055*height), control1: CGPoint(x: 0.60951*width, y: 0.26045*height), control2: CGPoint(x: 0.53915*width, y: 0.38381*height))
        path.addCurve(to: CGPoint(x: 0.0558*width, y: 0.45055*height), control1: CGPoint(x: 0.31072*width, y: 0.5173*height), control2: CGPoint(x: 0.17001*width, y: 0.5173*height))
        path.addLine(to: CGPoint(x: 0.09285*width, y: 0.38559*height))
        path.addCurve(to: CGPoint(x: 0.24037*width, y: 0.42555*height), control1: CGPoint(x: 0.13624*width, y: 0.411*height), control2: CGPoint(x: 0.18663*width, y: 0.42555*height))
        path.addCurve(to: CGPoint(x: 0.53535*width, y: 0.12695*height), control1: CGPoint(x: 0.40328*width, y: 0.42555*height), control2: CGPoint(x: 0.53535*width, y: 0.29186*height))
        path.addLine(to: CGPoint(x: 0.60951*width, y: 0.12695*height))
        path.closeSubpath()
        return path
    }

    func path33(in rect: CGRect) -> Path{
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.20033*width, y: 0.33918*height))
        path.addCurve(to: CGPoint(x: 0.19774*width, y: 0.32877*height), control1: CGPoint(x: 0.19933*width, y: 0.33608*height), control2: CGPoint(x: 0.1985*width, y: 0.33252*height))
        path.addCurve(to: CGPoint(x: 0.19358*width, y: 0.27295*height), control1: CGPoint(x: 0.19374*width, y: 0.30831*height), control2: CGPoint(x: 0.19349*width, y: 0.28055*height))
        path.addLine(to: CGPoint(x: 0.19283*width, y: 0.27267*height))
        path.addCurve(to: CGPoint(x: 0.16573*width, y: 0.30466*height), control1: CGPoint(x: 0.18324*width, y: 0.29077*height), control2: CGPoint(x: 0.16573*width, y: 0.30466*height))
        path.addLine(to: CGPoint(x: 0.16573*width, y: 0.30438*height))
        path.addLine(to: CGPoint(x: 0.16473*width, y: 0.29593*height))
        path.addCurve(to: CGPoint(x: 0.17982*width, y: 0.27961*height), control1: CGPoint(x: 0.17148*width, y: 0.29228*height), control2: CGPoint(x: 0.17982*width, y: 0.27961*height))
        path.addLine(to: CGPoint(x: 0.17282*width, y: 0.21432*height))
        path.addLine(to: CGPoint(x: 0.17073*width, y: 0.21451*height))
        path.addCurve(to: CGPoint(x: 0.1393*width, y: 0.26423*height), control1: CGPoint(x: 0.16048*width, y: 0.24209*height), control2: CGPoint(x: 0.1393*width, y: 0.26423*height))
        path.addLine(to: CGPoint(x: 0.13914*width, y: 0.30362*height))
        path.addLine(to: CGPoint(x: 0.13889*width, y: 0.36375*height))
        path.addCurve(to: CGPoint(x: 0.20041*width, y: 0.33927*height), control1: CGPoint(x: 0.17165*width, y: 0.36479*height), control2: CGPoint(x: 0.19999*width, y: 0.33974*height))
        path.addLine(to: CGPoint(x: 0.20033*width, y: 0.33918*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.25876*width, y: 0.40939*height))
        path.addCurve(to: CGPoint(x: 0.39018*width, y: 0.38235*height), control1: CGPoint(x: 0.2808*width, y: 0.42645*height), control2: CGPoint(x: 0.33156*width, y: 0.4456*height))
        path.addCurve(to: CGPoint(x: 0.4322*width, y: 0.25302*height), control1: CGPoint(x: 0.44478*width, y: 0.32345*height), control2: CGPoint(x: 0.43389*width, y: 0.26128*height))
        path.addCurve(to: CGPoint(x: 0.43202*width, y: 0.2523*height), control1: CGPoint(x: 0.43211*width, y: 0.25257*height), control2: CGPoint(x: 0.43202*width, y: 0.2523*height))
        path.addCurve(to: CGPoint(x: 0.31488*width, y: 0.24694*height), control1: CGPoint(x: 0.38277*width, y: 0.21709*height), control2: CGPoint(x: 0.31488*width, y: 0.24694*height))
        path.addLine(to: CGPoint(x: 0.31461*width, y: 0.25039*height))
        path.addCurve(to: CGPoint(x: 0.34361*width, y: 0.26527*height), control1: CGPoint(x: 0.32326*width, y: 0.24939*height), control2: CGPoint(x: 0.34146*width, y: 0.25339*height))
        path.addCurve(to: CGPoint(x: 0.34378*width, y: 0.26664*height), control1: CGPoint(x: 0.34369*width, y: 0.26573*height), control2: CGPoint(x: 0.34378*width, y: 0.26618*height))
        path.addCurve(to: CGPoint(x: 0.30756*width, y: 0.30321*height), control1: CGPoint(x: 0.34557*width, y: 0.28597*height), control2: CGPoint(x: 0.323*width, y: 0.30602*height))
        path.addCurve(to: CGPoint(x: 0.26759*width, y: 0.23841*height), control1: CGPoint(x: 0.29632*width, y: 0.30112*height), control2: CGPoint(x: 0.28062*width, y: 0.2974*height))
        path.addLine(to: CGPoint(x: 0.26759*width, y: 0.23823*height))
        path.addCurve(to: CGPoint(x: 0.26724*width, y: 0.17788*height), control1: CGPoint(x: 0.26117*width, y: 0.20928*height), control2: CGPoint(x: 0.2634*width, y: 0.19013*height))
        path.addCurve(to: CGPoint(x: 0.28436*width, y: 0.16445*height), control1: CGPoint(x: 0.27152*width, y: 0.16408*height), control2: CGPoint(x: 0.28196*width, y: 0.15419*height))
        path.addCurve(to: CGPoint(x: 0.28436*width, y: 0.1777*height), control1: CGPoint(x: 0.28508*width, y: 0.16717*height), control2: CGPoint(x: 0.28517*width, y: 0.17153*height))
        path.addCurve(to: CGPoint(x: 0.26956*width, y: 0.20656*height), control1: CGPoint(x: 0.28267*width, y: 0.19031*height), control2: CGPoint(x: 0.27634*width, y: 0.20066*height))
        path.addCurve(to: CGPoint(x: 0.27152*width, y: 0.23015*height), control1: CGPoint(x: 0.26813*width, y: 0.21109*height), control2: CGPoint(x: 0.26956*width, y: 0.22071*height))
        path.addCurve(to: CGPoint(x: 0.27785*width, y: 0.25411*height), control1: CGPoint(x: 0.27419*width, y: 0.24231*height), control2: CGPoint(x: 0.27785*width, y: 0.25411*height))
        path.addCurve(to: CGPoint(x: 0.32995*width, y: 0.12606*height), control1: CGPoint(x: 0.32469*width, y: 0.19875*height), control2: CGPoint(x: 0.33495*width, y: 0.1512*height))
        path.addCurve(to: CGPoint(x: 0.32353*width, y: 0.11163*height), control1: CGPoint(x: 0.32871*width, y: 0.1198*height), control2: CGPoint(x: 0.32648*width, y: 0.1149*height))
        path.addCurve(to: CGPoint(x: 0.25126*width, y: 0.12824*height), control1: CGPoint(x: 0.31033*width, y: 0.09665*height), control2: CGPoint(x: 0.28312*width, y: 0.09774*height))
        path.addLine(to: CGPoint(x: 0.25109*width, y: 0.12806*height))
        path.addCurve(to: CGPoint(x: 0.24377*width, y: 0.1355*height), control1: CGPoint(x: 0.24868*width, y: 0.13032*height), control2: CGPoint(x: 0.24627*width, y: 0.13278*height))
        path.addCurve(to: CGPoint(x: 0.21192*width, y: 0.18423*height), control1: CGPoint(x: 0.22985*width, y: 0.15047*height), control2: CGPoint(x: 0.21924*width, y: 0.16572*height))
        path.addLine(to: CGPoint(x: 0.2121*width, y: 0.18423*height))
        path.addCurve(to: CGPoint(x: 0.20077*width, y: 0.27462*height), control1: CGPoint(x: 0.203*width, y: 0.2071*height), control2: CGPoint(x: 0.19916*width, y: 0.23523*height))
        path.addCurve(to: CGPoint(x: 0.20532*width, y: 0.31192*height), control1: CGPoint(x: 0.2013*width, y: 0.28787*height), control2: CGPoint(x: 0.20291*width, y: 0.30031*height))
        path.addCurve(to: CGPoint(x: 0.25849*width, y: 0.40921*height), control1: CGPoint(x: 0.21585*width, y: 0.36211*height), control2: CGPoint(x: 0.24145*width, y: 0.39596*height))
        path.addLine(to: CGPoint(x: 0.25876*width, y: 0.40939*height))
        path.closeSubpath()
        return path
    }
}


#Preview {
    FestIcon(color1: Color(#colorLiteral(red: 0.6043365598, green: 0.1695636213, blue: 0.3733027875, alpha: 1)), color2: Color(#colorLiteral(red: 0.8892669082, green: 0.6943174005, blue: 0.4936971068, alpha: 1)), color3: Color(#colorLiteral(red: 0.3980279863, green: 0.6735672355, blue: 0.08811444789, alpha: 1)))
        .frame(width: 200,height: 200)
        .background(Color(.red))
        .mask(                                 // 再把整体裁小一圈
            GeometryReader { geo in
                let w = geo.size.width  * 0.75
                let h = geo.size.height * 0.75
                Rectangle()
                    .frame(width: w, height: h)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        )
}
