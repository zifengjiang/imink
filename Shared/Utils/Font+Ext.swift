import Foundation
import SwiftUI



extension Font {
    enum CustomFont: String {
        case font1 = "DFPZongYiW7"
        case Splatoon1 = "Splatfont 1 v1.008"
        case Splatoon2 = "Splatoon2"
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

    static func splatoonFont2(size: CGFloat) -> Font {
        customFont(.Splatoon2, size: size)
    }

    static func splatoonFont(size: CGFloat) -> Font {
        customFont(.font1, size: size)
    }

}

