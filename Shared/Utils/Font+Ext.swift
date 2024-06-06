import Foundation
import SwiftUI



extension Font {
    enum CustomFont: String {
        case font1 = "DFPZongYiW7-GB"
        case Splatoon1 = "Splatfont 1 v1.008"
        case zhHant = "DFP222"
        case ko = "AsiaKERIN-M"
        case ja = "FOT-Kurokane Std EB"
    }

    static func customFont(_ font: CustomFont, size: CGFloat) -> Font {

        if let uiFont = UIFont(name: font.rawValue, size: size) {
            return Font(uiFont)
        } else {
                // 如果字体加载失败，返回系统默认字体
            return Font.system(size: size)
        }
    }

    static func splatoonFont1(size: CGFloat) -> Font {
        customFont(.Splatoon1, size: size)
    }



    static func splatoonFont(size: CGFloat) -> Font {
        let currentLanguage = Locale.preferredLanguages.first ?? "en"
        switch currentLanguage {
        case "zh-Hans-US":
            return customFont(.font1, size: size)
        case "ja-US":
            return customFont(.ja, size: size)
        case "kr-US":
            return customFont(.ko, size: size)
        case "zh-Hant-US":
            return customFont(.zhHant, size: size)
        default:
            return customFont(.font1, size: size)
        }
//        customFont(.font1, size: size)
    }

}

