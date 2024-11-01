//
//  IndicatorsOverlay.swift
//  IndicatorsKit
//
//  Created by royal on 17/07/2022.
//

import SwiftUI

@available(iOS 17.0, *)
public struct IndicatorsOverlay: View {
	@Environment(\.ikEnableHaptics) private var enableHaptics
	@Bindable private var model: Indicators
	var insets: EdgeInsets

	public init(
		model: Indicators,
		insets: EdgeInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
	) {
		self.model = model
		self.insets = insets
	}

	public var body: some View {
        ZStack(alignment: .top) {
			let indicatorsCount = model.indicators.count
			ForEach(Array(model.indicators.enumerated()), id: \.element.id) { index, indicator in
				IndicatorView(
					indicator: indicator,
					onDismiss: { onDismiss(indicator) },
					onToggleExpansion: { onToggleExpansion(indicator, isExpanded: $0) }
				)
				.scaleEffect(scale(for: index, indicatorsCount: indicatorsCount))
				.padding(.horizontal)
				.padding(insets)
				.transition(
					.asymmetric(
						insertion: .move(edge: .top),
						removal: .move(edge: .top).combined(with: .opacity)
					)
				)
				.zIndex(Double(index))
			}
		}
		.id(ViewID.indicatorsOverlayView)
	}
}

// MARK: - IndicatorsOverlay+Private

private extension IndicatorsOverlay {
	func onToggleExpansion(_ indicator: Indicator, isExpanded: Bool) {
		#if canImport(UIKit)
		if enableHaptics {
			UIImpactFeedbackGenerator(style: .soft).impactOccurred()
		}
		#endif

		if isExpanded {
			model.dismissTimer(for: indicator.id)
		} else {
			model.setupTimerIfNeeded(for: indicator)
		}
	}

	@MainActor
	func onDismiss(_ indicator: Indicator) {
		model.dismiss(indicator)
	}

	func scale(for index: Int, indicatorsCount: Int) -> Double {
		let indexFlipped = Double(indicatorsCount - index) - 1
		return 1 - (indexFlipped * 0.2)
	}
}

// MARK: - IndicatorsOverlay+ViewID

private extension IndicatorsOverlay {
	enum ViewID: String {
		case indicatorsOverlayView = "IndicatorsOverlayView"
	}
}

// MARK: - Previews

#if DEBUG
struct ContentView: View {
    var indicators: Indicators = Indicators()
    @State private var progress: Double = 0.0
    @State private var progressIndicatorId: String = UUID().uuidString

    var body: some View {
        ZStack {
            NavigationStack{
                Button("Show Progress Indicator") {
                    let progressIndicator = Indicator.init(id: progressIndicatorId, title: "Downloading", progress: progress)
                    indicators.display(progressIndicator)
                    startProgressUpdate()
                }
            }
        }
        .overlay(alignment: .top) {
            IndicatorsOverlay(model: indicators)
        } 
    }

    func startProgressUpdate() {
        progress = 0.0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if progress < 1.0 {
                progress += 0.1
                indicators.updateProgress(for: progressIndicatorId, progress: progress)
            } else {
                timer.invalidate()
                indicators.dismiss(with: progressIndicatorId)
                indicators.display(.init(id: UUID().uuidString, icon: .systemImage("checkmark.circle.fill"), title: "Download", subtitle: "DownloadDownloadDownloadDownloadDownloadDownloadDownloadDownloadDownloadDownload", expandedText:"DownloadDownloadDownloadDownloadDownloadDownloadDownload",dismissType: .automatic))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


#Preview {
    
	IndicatorsOverlay(
		model: .preview(
			indicators: [
				.init(id: "i1", icon: .progressIndicator, title: "Indicator 1", subtitle: "Indicator Subtitle", expandedText: "Expanded Text", dismissType: .manual),
				.init(id: "i1", icon: .systemImage("rectangle.arrowtriangle.2.inward"), title: "Indicator 1", subtitle: "Indicator Subtitle", expandedText: "Expanded Text", dismissType: .automatic),
				.init(id: "i2", icon: .progressIndicator, title: "Indicator 2", subtitle: "Indicator Subtitle", expandedText: "Expanded Text", dismissType: .manual),
				.init(id: "i2", icon: .systemImage("rectangle.arrowtriangle.2.inward"), title: "Indicator 2", subtitle: "Indicator Subtitle", expandedText: "Expanded Text", dismissType: .automatic),
			]
		)
	)
	#if os(iOS)
	.frame(maxHeight: .infinity, alignment: .top)
	#elseif os(macOS)
	.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	#endif
}
#endif
