//
//  LoginView.swift
//  imink
//
//  Created by Jone Wang on 2021/3/10.
//

import SwiftUI
import SwiftyJSON

struct LoginViewModifier: ViewModifier {
    
    var isLogin: Bool
    var iconName: String? = nil
    var backgroundColor: Color? = nil
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .grayscale(isLogin ? 0 : 0.9999)

            if !isLogin {
                LoginView(
                    iconName: iconName,
                    backgroundColor: backgroundColor
                )
            }
        }
    }
}

struct LoginView: View {
    
    var iconName: String? = nil
    var backgroundColor: Color? = nil
    @StateObject var viewModel = LoginViewModel()

    var body: some View {
        VStack(spacing: 14) {
            if let iconName = iconName {
                FixVectorImage(iconName, tintColor: Color.appLabel)
                    .frame(width: 52, height: 47)
            }
            
            VStack(spacing: 6) {
                Text("Log in to sync your data")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.appLabel)

                Text("Connect your Nintendo Account to load SplatNet 3 records, schedules, and player data.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appLabel.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Button {
                Task {
                    await viewModel.loginFlow()
                }
            } label: {
                Text("Log in with Nintendo Account")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
            }
            .frame(height: 44)
            .frame(minWidth: 223)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .disabled(viewModel.status == .loading)

            Text("Authentication uses Nintendo's Coral API through nxapi-znca-api. Your session token is stored locally for sync.")
                .font(.system(size: 11))
                .foregroundColor(Color.appLabel.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor != nil ? backgroundColor : Color.listBackground.opacity(0.8))
    }

    
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .frame(width: 343, height: 267)
            .previewLayout(.sizeThatFits)
    }
}
