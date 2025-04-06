//
//  IndicatorView.swift
//  IndicatorsKit
//
//  Created by royal on 17/07/2022.
//

import SwiftUI

// MARK: - IndicatorView

struct IndicatorView: View {
	var indicator: Indicator
	var onDismiss: (() -> Void)?
	var onToggleExpansion: ((Bool) -> Void)?

	@Namespace private var animationNamespace

	@State private var isPressed = false
	@State private var isExpanded = false
	@State private var isIconVisible = false
	@State private var dragOffset = CGSize.zero
    @State private var rotationAngle: Double = 0

	private let dragInWrongDirectionMultiplier: Double = 0.028
	private let dragThreshold: Double = 20

	private let backgroundShape: some Shape = RoundedRectangle(cornerRadius: 28, style: .circular)

	private var minWidth: Double {
		if indicator.subtitle != nil {
			return 112
		}
		return 64
	}
	private let maxWidth: Double = 300

	private let spacingVertical: Double = 8
	private var spacingHorizontal: Double {
		if isExpanded {
			return 6
		}
		if indicator.subtitle != nil {
			return 14
		}
		return 6
	}

	private var paddingHorizontal: Double {
		if isExpanded {
			return paddingVertical
		}
		if indicator.subtitle != nil {
			return 26
		}
		return 18
	}
	private var paddingVertical: Double {
		if isExpanded {
			return 18
		}
		if indicator.subtitle != nil {
			return 12
		}
		return 12
	}

	private var iconFont: Font {
		if isExpanded {
			return titleFont
		}
		if indicator.subtitle != nil {
			return .title2
		}
		return .footnote
	}

	private var titleFont: Font {
		if isExpanded {
			return .title3
		}
		return .footnote
	}

	private var dragGesture: some Gesture {
		DragGesture()
			.onChanged {
                    dragOffset.width = $0.translation.width * dragInWrongDirectionMultiplier
                    dragOffset.height = $0.translation.height < 0 ? $0.translation.height : $0.translation.height * dragInWrongDirectionMultiplier
			}
            .onEnded {
                withAnimation(.snappy) {
                    dragOffset = .zero
                }

                    if $0.translation.height < dragThreshold {
                        if indicator.isUserDismissible{
                            onDismiss?()
                        }
                    } else if $0.translation.height > 0 {
                        if indicator.expandedText != nil {
                            toggleExpansionIfPossible()
                        }
                    }

            }
	}

	init(
		indicator: Indicator,
		onDismiss: (() -> Void)? = nil,
		onToggleExpansion: ((Bool) -> Void)? = nil
	) {
		self.indicator = indicator
		self.onDismiss = onDismiss
		self.onToggleExpansion = onToggleExpansion
	}

	#if DEBUG
	init(
		indicator: Indicator,
		onDismiss: (() -> Void)? = nil,
		onToggleExpansion: ((Bool) -> Void)? = nil,
		isExpanded: Bool = false
	) {
		self.indicator = indicator
		self.onDismiss = onDismiss
		self.onToggleExpansion = onToggleExpansion
		self._isExpanded = .init(initialValue: isExpanded)
	}
	#endif

	var body: some View {
		VStack(spacing: spacingVertical) {
			HStack(spacing: spacingHorizontal) {
				if let icon = indicator.icon {
					Group {
						switch icon {
						case .image(let image):
							image
								.onAppear { isIconVisible = false }
						case .systemImage(let systemName):
							Image(systemName: systemName)
								.font(iconFont)
								.fontWeight(.medium)
//								.foregroundStyle(indicator.style.iconStyle)
								.foregroundColor(indicator.style.tintColor)
								.symbolRenderingMode(.hierarchical)
								.symbolEffect(.bounce, options: .nonRepeating, value: isIconVisible)
//								.transition(.symbolEffect(.appear))
								.onAppear { isIconVisible = true }
								.onDisappear { isIconVisible = false }
                        case .success:
                            Image(.checkmark)
                                .resizable()
                                .scaledToFit()
                                .overlay(Color(.accent))
                                .mask{
                                    Image(.checkmark)
                                        .resizable()
                                        .scaledToFit()
                                }
                                .frame(width: 20, height: 20)
                        case .progressIndicator, .progressBar:
                            Image("TabBarHome")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.accent)
                                .frame(width: 20, height: 20)
                                .rotationEffect(.degrees(rotationAngle))
                                .onAppear {
                                    rotationAngle = 360
                                    isIconVisible = false
                                }
                                .animation(
                                    Animation.linear(duration: 1)
                                        .repeatForever(autoreverses: false),
                                    value: rotationAngle
                                )
                        }
					}
					.geometryGroup()
					.padding(.leading, -2)
					.id(ViewID.iconView)
				}

				VStack {

					Text(indicator.title)
						.font(titleFont)
						.fontWeight(.medium)
						.lineLimit(isExpanded ? 2 : 1)
						.foregroundStyle(.primary)
						.foregroundColor(indicator.style.tintColor)
						.frame(
							maxWidth: isExpanded ? .infinity : nil,
							alignment: isExpanded ? .leading : .center
						)
						.fixedSize(horizontal: !isExpanded && indicator.title.count < 16, vertical: false)
//						.geometryGroup()
						.id(ViewID.titleLabel)

                    if indicator.progress != nil {
                        ProgressView(value: indicator.progress)
                            .progressViewStyle(.linear)
                            .tint(indicator.style.tintColor)
                            .frame(width: isExpanded ? 300 : 200)
                    }

					if !isExpanded, let content = indicator.subtitle {
						Text(content)
							.font(.footnote)
							.fontWeight(.medium)
							.lineLimit(2)
							.foregroundStyle(.secondary)
							.matchedGeometryEffect(
								id: AnimationID.subtitleOrExpandedTextLabel,
								in: animationNamespace,
								properties: .position,
								anchor: .topLeading
							)
							.transition(.blurReplace)
							.id(ViewID.subtitleLabel)
					}
				}
				.multilineTextAlignment(isExpanded ? .leading : .center)
			}

			if isExpanded, let content = indicator.expandedText {
				Text(content)
					.font(.footnote)
					.fontWeight(.medium)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
					.matchedGeometryEffect(
						id: AnimationID.subtitleOrExpandedTextLabel,
						in: animationNamespace,
						properties: .position,
						anchor: .topLeading
					)
					.transition(.blurReplace)
					.id(ViewID.expandedContentLabel)
			}
		}
		.padding(.horizontal, paddingHorizontal)
		.padding(.vertical, paddingVertical)
		.frame(minWidth: minWidth)
		.background(.regularMaterial, in: backgroundShape)
		.mask(backgroundShape)
		.scaleEffect(isPressed ? 0.96 : 1)
		.offset(dragOffset)
		.shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 0)
		.opacity(isPressed ? 0.8 : 1)
		.gesture(dragGesture)
		.animation(.spring, value: isExpanded)
		.animation(.spring, value: isPressed)
		.onLongPressGesture(minimumDuration: 0) {
			didTapIndicator()
		} onPressingChanged: {
			if indicator.action != nil {
				self.isPressed = $0
			}
		}
	}
}

// MARK: - IndicatorView+Identifiable

extension IndicatorView: Identifiable {
	var id: String { indicator.id }
}

// MARK: - IndicatorView+Private

private extension IndicatorView {
	func toggleExpansionIfPossible() {
		guard indicator.expandedText != nil else {
			return
		}

		isExpanded.toggle()
		onToggleExpansion?(isExpanded)
	}

	func didTapIndicator() {
		guard let action = indicator.action else {
			return
		}
		switch action {
		case .toggleExpansion:
			toggleExpansionIfPossible()
		case .execute(let actionToExecute):
			actionToExecute()
		}
	}
}

// MARK: - IndicatorView+ViewID

private extension IndicatorView {
	enum ViewID: String {
		case iconView = "IconView"
		case titleLabel = "TitleLabel"
		case subtitleLabel = "SubtitleLabel"
		case expandedContentLabel = "ExpandedContentLabel"
	}
}

// MARK: - IndicatorView+AnimationID

private extension IndicatorView {
	enum AnimationID: String {
		case subtitleOrExpandedTextLabel = "SubtitleOrExpandedTextLabel"
	}
}

// MARK: - Previews

#if DEBUG
#Preview("Title", traits: .sizeThatFitsLayout) {
	IndicatorView(indicator: .title)
}

#Preview("Icon + Title", traits: .sizeThatFitsLayout) {
	IndicatorView(indicator: .titleIcon)
}

#Preview("Title + Subtitle", traits: .sizeThatFitsLayout) {
	IndicatorView(indicator: .titleSubtitleExpanded)
}

#Preview("Icon + Title + Subtitle", traits: .sizeThatFitsLayout) {
	IndicatorView(indicator: .titleSubtitleExpandedIcon)
}

#Preview("Title + Subtitle (Expanded)", traits: .sizeThatFitsLayout) {
	IndicatorView(indicator: .titleSubtitleExpanded, isExpanded: true)
}

#Preview("Icon + Title + Subtitle (Expanded)", traits: .sizeThatFitsLayout) {
	IndicatorView(indicator: .titleSubtitleExpandedIcon, isExpanded: true)
}

#Preview("Progress", traits: .sizeThatFitsLayout) {
    IndicatorView(indicator: .init(id: "1213", icon: .progressBar, title: "正在加载", subtitle: nil, expandedText: nil, dismissType: .manual, style: .default, action: .none, progress: nil, isUserDismissible: true), isExpanded: false)
}
#endif
