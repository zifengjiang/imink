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

        var titleKey: LocalizedStringKey {
            switch self {
            case .web:
                return "login_method_web"
            case .sessionToken:
                return "login_method_token"
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
                    .font(.appHeadline)
                    .foregroundColor(Color.appLabel)

                Text("login_subtitle")
                    .font(.appMono)
                    .foregroundColor(Color.appLabel.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Picker("login_method_picker", selection: $loginMethod) {
                ForEach(LoginMethod.allCases) { method in
                    Text(method.titleKey).tag(method)
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
                    Text("Log in with Nintendo Account")
                        .font(.appMono)
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
                    TextField("login_token_placeholder", text: $sessionToken)
                        .font(.appMono)
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
                        Text("login_with_session_token")
                            .font(.appMono)
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
                    .font(.appCaption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }

            Text("login_coral_disclaimer")
                .font(.appSubCaptionMono)
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
