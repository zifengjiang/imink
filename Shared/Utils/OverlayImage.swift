import SwiftUI

func overlayImageWithColor(imageName: String, color: Color) -> Image? {
        // 加载底层图片（背景图）
    guard let backgroundImage = UIImage(named: "\(imageName)00") else {
        return nil
    }

        // 加载覆盖图片（前景图）
    guard let overlayImage = UIImage(named: "\(imageName)01") else {
        return nil
    }

        // 创建一个图形上下文，大小为底图的大小
    UIGraphicsBeginImageContextWithOptions(backgroundImage.size, false, backgroundImage.scale)

        // 将底图绘制到上下文中
    backgroundImage.draw(in: CGRect(x: 0, y: 0, width: backgroundImage.size.width, height: backgroundImage.size.height))

        // 获取上下文
    guard let context = UIGraphicsGetCurrentContext() else {
            // 处理错误情况
        UIGraphicsEndImageContext()
        return nil
    }

        // 设置混合模式
    context.setBlendMode(.normal)

        // 将覆盖图片绘制到上下文中
    overlayImage.draw(in: CGRect(x: 0, y: 0, width: backgroundImage.size.width, height: backgroundImage.size.height))

        // 设置混合模式为源在目标上，即覆盖
    context.setBlendMode(.sourceAtop)


        // 将背景图片填充为指定颜色
    context.fill(CGRect(x: 0, y: 0, width: backgroundImage.size.width, height: backgroundImage.size.height))

        // 从上下文中获取混合后的图片
    guard let blendedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            // 处理错误情况
        UIGraphicsEndImageContext()
        return nil
    }

        // 关闭图形上下文
    UIGraphicsEndImageContext()

        // 返回 SwiftUI 的 Image 视图
    return Image(uiImage: blendedImage)
}

