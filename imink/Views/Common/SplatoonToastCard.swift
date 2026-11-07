//
//  SplatoonToastCard.swift
//  imink
//
//  「墨边贴纸」提示卡片：贴纸本体 + 胶带 + 墨边，成功/失败在角落盖一枚印章，
//  进行中用墨量液面表现进度。
//

import SwiftUI

// MARK: - SplatoonToastTone

/// 提示的语义状态，决定印章图形、墨色与进度条表现。
enum SplatoonToastTone: Equatable {
    case progress
    case success
    case failure
    case warning
    case info

    var ink: Color {
        switch self {
        case .progress:
            return .accentColor
        case .success:
            return .spGreen
        case .failure:
            return .spRed
        case .warning:
            return .spYellow
        case .info:
            return .appLabel
        }
    }

    /// 危险语义只在卡片边缘加一条斜纹，不侵占文字区域。
    var showsHazardStripe: Bool {
        switch self {
        case .failure, .warning:
            return true
        default:
            return false
        }
    }
}

extension Indicator {
    /// 由图标与进度推导状态，调用方继续按原有语义设置图标即可。
    var splatoonTone: SplatoonToastTone {
        switch icon {
        case .success:
            return .success
        case .progressIndicator, .progressBar:
            return (progress ?? 0) >= 1 ? .success : .progress
        case .systemImage(let name):
            return Self.tone(forSystemImageNamed: name)
        case .image, .none:
            return progress == nil ? .info : .progress
        }
    }

    /// 不会自动消失、需要外部驱动到终态的常驻任务（登录、导入、批量刷新等）。
    var isOngoingTask: Bool {
        if case .manual = dismissType {
            return true
        }
        return false
    }

    private static func tone(forSystemImageNamed name: String) -> SplatoonToastTone {
        if name.contains("checkmark") {
            return .success
        }
        if name.contains("xmark") {
            return .failure
        }
        if name.contains("exclamationmark") || name.contains("warning") {
            return .warning
        }
        return .info
    }
}

// MARK: - SplatoonToastCard

struct SplatoonToastCard: View {
    let indicator: Indicator
    var queuedTaskCount: Int = 0
    var onDismiss: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0

    private var tone: SplatoonToastTone { indicator.splatoonTone }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            if indicator.icon != nil {
                SplatoonToastStamp(
                    tone: tone,
                    icon: indicator.icon,
                    reduceMotion: reduceMotion
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(indicator.title)
                    .font(.splatoonFont(size: 15))
                    .foregroundStyle(Color.appLabel)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = indicator.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.splatoonFont(size: 12))
                        .foregroundStyle(Color.appLabel.opacity(0.62))
                        .lineLimit(2)
                }

                if let progress = indicator.progress {
                    inkLevel(max(0, min(1, progress)))
                }

                if let expandedText = indicator.expandedText, !expandedText.isEmpty {
                    Text(expandedText)
                        .font(.splatoonFont(size: 11))
                        .foregroundStyle(Color.appLabel.opacity(0.5))
                        .lineLimit(3)
                }
            }

            if queuedTaskCount > 0 {
                queuedTaskBadge
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 11)
        .background(stickerBackground)
        .overlay(alignment: .topLeading) { tape }
        .rotationEffect(.degrees(reduceMotion ? 0 : -1.2))
        .shadow(color: .black.opacity(0.18), radius: 9, x: 0, y: 4)
        .offset(y: dragOffset)
        .gesture(dismissGesture)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(indicator.progress == nil ? [] : .updatesFrequently)
        .accessibilityAction(named: Text("关闭")) {
            guard indicator.isUserDismissible else { return }
            onDismiss?()
        }
    }
}

// MARK: - SplatoonToastCard+Subviews

private extension SplatoonToastCard {
    var stickerBackground: some View {
        ZStack(alignment: .top) {
            Color.listItemBackground
            GrayscaleTextureView(
                texture: .bubble,
                foregroundColor: Color.appLabel.opacity(0.055),
                backgroundColor: .clear
            )
            if tone.showsHazardStripe {
                hazardStripe
                    .frame(height: 4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.appLabel.opacity(0.82), lineWidth: 1.6)
        }
    }

    var hazardStripe: some View {
        ZStack {
            tone.ink
            HazardStripeShape()
                .stroke(Color.listItemBackground.opacity(0.8), lineWidth: 2)
        }
    }

    var tape: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(tone.ink.opacity(0.3))
            .overlay {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .strokeBorder(tone.ink.opacity(0.26), lineWidth: 0.5)
            }
            .frame(width: 34, height: 11)
            .rotationEffect(.degrees(-24))
            .offset(x: 12, y: -4)
            .allowsHitTesting(false)
    }

    var queuedTaskBadge: some View {
        Text("+\(queuedTaskCount)")
            .font(.splatoonFont(size: 11))
            .foregroundStyle(Color.listItemBackground)
            .frame(minWidth: 20, minHeight: 20)
            .background(Color.appLabel.opacity(0.8), in: Capsule())
            .accessibilityLabel(Text("还有 \(queuedTaskCount) 项任务正在进行"))
    }

    func inkLevel(_ value: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.appLabel.opacity(0.12))

                Capsule(style: .continuous)
                    .fill(tone.ink)
                    .frame(width: max(proxy.size.width * value, value > 0 ? 6 : 0))
                    .overlay(alignment: .trailing) {
                        if value > 0.03 && value < 0.97 {
                            Circle()
                                .fill(tone.ink)
                                .frame(width: 7, height: 7)
                                .offset(x: 3)
                        }
                    }
            }
        }
        .frame(height: 7)
        .padding(.top, 2)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: value)
        .accessibilityValue(Text("\(Int(value * 100))%"))
    }

    var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard indicator.isUserDismissible else { return }
                dragOffset = min(0, value.translation.height)
            }
            .onEnded { value in
                guard indicator.isUserDismissible else { return }
                if value.translation.height < -24 {
                    onDismiss?()
                }
                withAnimation(reduceMotion ? .linear(duration: 0.1) : .snappy) {
                    dragOffset = 0
                }
            }
    }
}

// MARK: - SplatoonToastStamp

/// 角落的「墨滴印章」：进行中是墨圈，终态是盖章式的方章。
struct SplatoonToastStamp: View {
    let tone: SplatoonToastTone
    let icon: Indicator.Icon?
    let reduceMotion: Bool

    @State private var stampScale: CGFloat = 1
    @State private var spin: Double = 0

    var body: some View {
        Group {
            if let image = Self.renderedImage(for: icon) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(tone.ink)
            } else if tone == .progress {
                spinner
            } else {
                Image(systemName: Self.symbolName(for: tone))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(tone.ink)
            }
        }
        .frame(width: 30, height: 30)
        .background {
            if tone == .progress {
                Circle()
                    .strokeBorder(tone.ink.opacity(0.85), lineWidth: 2)
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(tone.ink, lineWidth: 2.4)
                    .rotationEffect(.degrees(-6))
            }
        }
        .scaleEffect(stampScale)
        .onAppear { slamIfNeeded() }
        .onChange(of: tone) { _, _ in slamIfNeeded() }
    }

    private var spinner: some View {
        Image("TabBarHome")
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .rotationEffect(.degrees(reduceMotion ? 0 : spin))
            .onAppear {
                guard !reduceMotion else { return }
                spin = 360
            }
            .animation(
                reduceMotion ? nil : .linear(duration: 1.1).repeatForever(autoreverses: false),
                value: spin
            )
    }

    /// 盖章：先放大到位，再回弹收住。开启减弱动态效果时保持静止。
    private func slamIfNeeded() {
        guard !reduceMotion, tone != .progress else { return }
        stampScale = 1.55
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            stampScale = 1
        }
    }

    private static func symbolName(for tone: SplatoonToastTone) -> String {
        switch tone {
        case .success:
            return "checkmark"
        case .failure:
            return "xmark"
        case .warning:
            return "exclamationmark"
        case .progress, .info:
            return "ellipsis"
        }
    }

    /// 只有调用方直接塞进来的自定义图片才需要走位图路径。
    private static func renderedImage(for icon: Indicator.Icon?) -> Image? {
        if case .image(let image) = icon {
            return image
        }
        return nil
    }
}

// MARK: - HazardStripeShape

/// 斜纹：Splatoon 的警示语言，只在卡片顶边占一条细线。
struct HazardStripeShape: Shape {
    var spacing: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = -rect.height * 2
        while x < rect.width + rect.height * 2 {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height * 1.6, y: rect.minY))
            x += spacing
        }
        return path
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Progress", traits: .sizeThatFitsLayout) {
    SplatoonToastCard(
        indicator: Indicator(
            id: "progress",
            icon: .progressIndicator,
            title: "登录中",
            subtitle: "获取 sessionToken",
            dismissType: .manual,
            progress: 0.42
        )
    )
    .padding()
}

#Preview("Success", traits: .sizeThatFitsLayout) {
    SplatoonToastCard(
        indicator: Indicator(
            id: "success",
            icon: .success,
            title: "登录成功",
            subtitle: "正在完成登录...",
            dismissType: .after(2)
        )
    )
    .padding()
}

#Preview("Failure", traits: .sizeThatFitsLayout) {
    SplatoonToastCard(
        indicator: Indicator(
            id: "failure",
            icon: .systemImage("xmark.circle.fill"),
            title: "导入失败",
            subtitle: "数据库版本不兼容",
            dismissType: .after(5),
            style: .error
        )
    )
    .padding()
}
#endif
