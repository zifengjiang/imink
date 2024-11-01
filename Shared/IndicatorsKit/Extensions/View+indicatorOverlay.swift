//
//  View+indicatorOverlay.swift
//  IndicatorsKit
//
//  Created by royal on 17/07/2022.
//

import SwiftUI

public extension View {
	func indicatorOverlay(
		model: Indicators,
		alignment: Alignment = .top,
		insets: EdgeInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
	) -> some View {
		overlay(IndicatorsOverlay(model: model, insets: insets), alignment: alignment)
	}
}
