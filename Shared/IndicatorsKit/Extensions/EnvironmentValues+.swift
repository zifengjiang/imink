//
//  EnvironmentValues+.swift
//  IndicatorsKit
//
//  Created by royal on 12/08/2023.
//

import SwiftUI

public extension EnvironmentValues {
	struct IKEnableHapticsEnvironmentKey: EnvironmentKey {
		public static let defaultValue = true

		private init() { }
	}

	/// Enable Haptic Feedback for Indicator interactions.
	var ikEnableHaptics: IKEnableHapticsEnvironmentKey.Value {
		get { self[IKEnableHapticsEnvironmentKey.self] }
		set { self[IKEnableHapticsEnvironmentKey.self] = newValue }
	}
}
