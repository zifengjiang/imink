//
//  SplatoonToastOverlay.swift
//  imink
//
//  轻提示的统一出口：单槽位展示、连续提示排队、进行中转终态、减弱动态与朗读降级。
//

import SwiftUI
import UIKit

// MARK: - SplatoonToastSlot

/// 槽位规则：常驻任务优先占位，其余提示按到达顺序排队，一次只展示一条。
struct SplatoonToastSlot {
    var primary: Indicator?
    var queuedTaskCount: Int

    init(indicators: [Indicator]) {
        let ongoingTasks = indicators.filter(\.isOngoingTask)
        primary = ongoingTasks.first ?? indicators.first
        let occupiesSlot = primary?.isOngoingTask ?? false
        queuedTaskCount = max(0, ongoingTasks.count - (occupiesSlot ? 1 : 0))
    }
}

// MARK: - SplatoonToastOverlay

struct SplatoonToastOverlay: View {
    var model: Indicators
    var insets: EdgeInsets = EdgeInsets()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrivalDates: [String: Date] = [:]
    @State private var announcedSignature = ""
    @State private var lastAnnouncement = Date.distantPast

    var body: some View {
        let slot = SplatoonToastSlot(indicators: model.indicators)

        ZStack(alignment: .top) {
            if let indicator = slot.primary {
                SplatoonToastCard(
                    indicator: indicator,
                    queuedTaskCount: slot.queuedTaskCount,
                    onDismiss: { model.dismiss(indicator) }
                )
                .frame(maxWidth: 330)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(insets)
                .id(indicator.id)
                .transition(cardTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(cardAnimation, value: slot.primary?.id)
        .onChange(of: model.indicators.map(\.id), initial: true) { _, _ in
            enforceSlotPolicy()
        }
        .onChange(of: announcementSignature) { _, signature in
            announceIfNeeded(signature: signature)
        }
    }
}

// MARK: - SplatoonToastOverlay+Policy

private extension SplatoonToastOverlay {
    /// 排队的提示暂停倒计时；轮到它时重新开始计时，避免尚未展示就过期。
    /// 排队过久已失去时效的临时提示直接丢弃，不在很久之后突然弹出。
    func enforceSlotPolicy() {
        let indicators = model.indicators
        let slot = SplatoonToastSlot(indicators: indicators)
        let now = Date()

        let liveIDs = Set(indicators.map(\.id))
        arrivalDates = arrivalDates.filter { liveIDs.contains($0.key) }
        for indicator in indicators where arrivalDates[indicator.id] == nil {
            arrivalDates[indicator.id] = now
        }

        for indicator in indicators where indicator.id != slot.primary?.id {
            model.dismissTimer(for: indicator.id)
        }

        guard let primary = slot.primary else { return }
        let waited = now.timeIntervalSince(arrivalDates[primary.id] ?? now)
        guard primary.isOngoingTask || waited <= 8 else {
            arrivalDates[primary.id] = nil
            model.dismiss(primary)
            return
        }
        model.setupTimerIfNeeded(for: primary)
    }

    var announcementSignature: String {
        let slot = SplatoonToastSlot(indicators: model.indicators)
        guard let primary = slot.primary else { return "" }
        return "\(primary.id)|\(primary.title)"
    }

    func announceIfNeeded(signature: String) {
        guard !signature.isEmpty, signature != announcedSignature else { return }
        announcedSignature = signature
        guard UIAccessibility.isVoiceOverRunning else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAnnouncement) > 0.8 else { return }
        lastAnnouncement = now

        guard let primary = SplatoonToastSlot(indicators: model.indicators).primary else { return }
        var message = primary.title
        if let subtitle = primary.subtitle, !subtitle.isEmpty {
            message += "，" + subtitle
        }
        AccessibilityNotification.Announcement(message).post()
    }

    var cardTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .scale(scale: 1.06, anchor: .top)
                .combined(with: .opacity)
                .combined(with: .offset(y: -10)),
            removal: .offset(y: -12).combined(with: .opacity)
        )
    }

    var cardAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.36, dampingFraction: 0.78)
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    let model = Indicators()
    return VStack { }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.listBackground)
        .overlay {
            SplatoonToastOverlay(model: model)
        }
        .task {
            model.display(.init(
                id: "login",
                icon: .progressIndicator,
                title: "登录中",
                subtitle: "获取 sessionToken",
                dismissType: .manual,
                progress: 0.35
            ))
        }
}
#endif
