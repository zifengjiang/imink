import SwiftUI
import Foundation

// 铭牌设置数据模型
struct NameplateSettings: Codable {
    var customName: String
    var customByname: String
    var customNameId: String
    var selectedBackground: String
    var selectedBadges: [String?]
    var selectedTextColorComponents: ColorComponents
    
    // 默认设置
    static let defaultSettings = NameplateSettings(
        customName: "自定义玩家",
        customByname: "自定义称号",
        customNameId: "0000",
        selectedBackground: "Npl_Tutorial00",
        selectedBadges: [nil, nil, nil],
        selectedTextColorComponents: ColorComponents(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    )
}

// Color 的可编码组件
struct ColorComponents: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    init(from color: Color) {
        // 将 SwiftUI Color 转换为 UIColor 再提取组件
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }
    
    func toColor() -> Color {
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

