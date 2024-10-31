import SwiftUI

extension View {
    func asUIImage(size: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage {
        let controller = UIHostingController(rootView: self)
        controller.view.bounds = CGRect(origin: .zero, size: size)

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)

        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}


extension View {
        /// 将视图渲染为 UIImage 后存储
    func captureAsUIImage(size: CGSize, scale: CGFloat = UIScreen.main.scale, completion: @escaping (UIImage?) -> Void) -> some View {
        modifier(CaptureAsUIImageModifier(size: size, scale: scale, completion: completion))
    }
}

struct CaptureAsUIImageModifier: ViewModifier {
    let size: CGSize
    let scale: CGFloat
    let completion: (UIImage?) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                    let image = content.asUIImage(size: size, scale: scale)
                    completion(image)
            }
    }
}
