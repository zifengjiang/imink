//
//  AppState.swift
//  imink
//
//  Created by 姜锋 on 10/5/24.
//

import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isLogin: Bool = AppUserDefaults.shared.sessionToken != nil

}
