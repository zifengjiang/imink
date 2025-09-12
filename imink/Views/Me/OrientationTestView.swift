import SwiftUI
import UIKit

struct OrientationTestView: View {
    @State private var currentOrientation: UIDeviceOrientation = UIDevice.current.orientation
    @State private var orientationString: String = ""
    @State private var interfaceOrientation: UIInterfaceOrientation = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.interfaceOrientation ?? .portrait
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("设备方向测试")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                
                VStack(alignment: .leading, spacing: 15) {
                    Group {
                        Text("当前设备方向:")
                            .font(.headline)
                        Text(orientationDescription(currentOrientation))
                            .font(.body)
                            .foregroundColor(.blue)
                            .padding(.leading)
                        
                        Text("界面方向:")
                            .font(.headline)
                        Text(interfaceOrientationDescription(interfaceOrientation))
                            .font(.body)
                            .foregroundColor(.green)
                            .padding(.leading)
                        
                        Text("原始值:")
                            .font(.headline)
                        Text("UIDeviceOrientation: \(currentOrientation.rawValue)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.leading)
                        Text("UIInterfaceOrientation: \(interfaceOrientation.rawValue)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.leading)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Button("刷新方向信息") {
                    updateOrientation()
                    Haptics.generateIfEnabled(.light)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                Spacer()
            }
            .navigationTitle("方向测试")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updateOrientation()
                startOrientationNotifications()
            }
            .onDisappear {
                stopOrientationNotifications()
            }
        }
    }
    
    private func orientationDescription(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait:
            return "竖屏 (Portrait)"
        case .portraitUpsideDown:
            return "倒立竖屏 (Portrait Upside Down)"
        case .landscapeLeft:
            return "左横屏 (Landscape Left)"
        case .landscapeRight:
            return "右横屏 (Landscape Right)"
        case .faceUp:
            return "屏幕朝上 (Face Up)"
        case .faceDown:
            return "屏幕朝下 (Face Down)"
        case .unknown:
            return "未知方向 (Unknown)"
        @unknown default:
            return "未定义方向"
        }
    }
    
    private func interfaceOrientationDescription(_ orientation: UIInterfaceOrientation) -> String {
        switch orientation {
        case .portrait:
            return "界面竖屏 (Portrait)"
        case .portraitUpsideDown:
            return "界面倒立竖屏 (Portrait Upside Down)"
        case .landscapeLeft:
            return "界面左横屏 (Landscape Left)"
        case .landscapeRight:
            return "界面右横屏 (Landscape Right)"
        case .unknown:
            return "界面未知方向 (Unknown)"
        @unknown default:
            return "界面未定义方向"
        }
    }
    
    private func updateOrientation() {
        currentOrientation = UIDevice.current.orientation
        interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .portrait
    }
    
    private func startOrientationNotifications() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            updateOrientation()
        }
    }
    
    private func stopOrientationNotifications() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
}

#Preview {
    OrientationTestView()
}

