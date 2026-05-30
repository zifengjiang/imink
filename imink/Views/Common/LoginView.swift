//
//  LoginView.swift
//  imink
//
//  Created by Jone Wang on 2021/3/10.
//

import SwiftUI
import SwiftyJSON

struct LoginViewModifier: ViewModifier {
    @ObservedObject private var appState = AppState.shared
    
    var isLogin: Bool
    var iconName: String? = nil
    var backgroundColor: Color? = nil
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .grayscale(appState.isLogin ? 0 : 0.9999)

            if !appState.isLogin {
                LoginView(
                    iconName: iconName,
                    backgroundColor: backgroundColor
                )
            }
        }
    }
}

struct LoginView: View {
    private enum LoginMethod: String, CaseIterable, Identifiable {
        case web
        case sessionToken

        var id: String { rawValue }

        var title: String {
            switch self {
            case .web:
                return "网页登录"
            case .sessionToken:
                return "Token 登录"
            }
        }
    }
    
    var iconName: String? = nil
    var backgroundColor: Color? = nil
    @StateObject var viewModel = LoginViewModel()
    @State private var loginMethod: LoginMethod = .web
    @State private var sessionToken = ""

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

            Picker("登录方式", selection: $loginMethod) {
                ForEach(LoginMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            if loginMethod == .web {
                Button {
                    Task {
                        await viewModel.loginFlow()
                    }
                } label: {
                    Text("任天堂账号登录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                }
                .frame(height: 44)
                .frame(minWidth: 223)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(viewModel.status == .loading)
            } else {
                VStack(spacing: 10) {
                    TextField("粘贴 Nintendo session token", text: $sessionToken)
                        .font(.system(size: 13))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.oneTimeCode)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(Color.listItemBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        }

                    Button {
                        Task {
                            await viewModel.loginWithSessionToken(sessionToken)
                        }
                    } label: {
                        Text("使用 Session Token 登录")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                    }
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(SessionTokenLoginInput.normalized(sessionToken) == nil ? Color.secondary.opacity(0.45) : Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(viewModel.status == .loading || SessionTokenLoginInput.normalized(sessionToken) == nil)
                }
                .frame(maxWidth: 300)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }

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
