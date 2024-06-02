// Source: https://betterprogramming.pub/implement-touch-events-in-swiftui-b3a2b0700fd4

import SwiftUI

struct TouchDownAndTouchUpGestureView: UIViewRepresentable {
    let touchDownCallBack: (() -> Void)
    let touchMovedCallBack: ((CGFloat) -> Void)
    let touchUpCallBack: (() -> Void)

    func makeUIView(context: UIViewRepresentableContext<Self>) -> Self.UIViewType {
        let view = UIView(frame: .zero)
        let tap = SingleScrollAndLongpressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        return view
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var touchDownCallback: (() -> Void)
        var touchMovedCallBack: ((CGFloat) -> Void)
        var touchUpCallback: (() -> Void)

        init(touchDownCallback: @escaping (() -> Void), touchMovedCallBack: @escaping ((CGFloat) -> Void), touchUpCallback: @escaping (() -> Void)) {
            self.touchDownCallback = touchDownCallback
            self.touchMovedCallBack = touchMovedCallBack
            self.touchUpCallback = touchUpCallback
        }

        @objc func tap(gesture: SingleScrollAndLongpressGestureRecognizer) {
            switch gesture.state{
            case .began:
                self.touchDownCallback()
            case .changed:
                self.touchMovedCallBack(gesture.distance)
            case .cancelled, .ended:
                self.touchUpCallback()
            case .possible, .failed:
                break
            @unknown default:
                print("未知のケース", gesture.state)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

    }
    func makeCoordinator() -> Coordinator {
        Coordinator(touchDownCallback: touchDownCallBack, touchMovedCallBack: touchMovedCallBack, touchUpCallback: touchUpCallBack)
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<Self>) {}
}

final class SingleScrollAndLongpressGestureRecognizer: UIGestureRecognizer {
    var startLocation: CGPoint = .zero
    var distance: CGFloat = .zero

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.state == .possible {
            self.startLocation = touches.first?.location(in: nil) ?? .zero
            self.state = .began
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        self.state = .cancelled
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        self.state = .changed
        let location = touches.first?.location(in: nil) ?? .zero
        let dx = startLocation.x - location.x
        let dy = startLocation.y - location.y
        self.distance = sqrt(dx*dx + dy*dy)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        self.state = .ended
        self.startLocation = .zero
        self.distance = .zero
    }
}
