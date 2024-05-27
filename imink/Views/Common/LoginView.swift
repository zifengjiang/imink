//
//  LoginView.swift
//  imink
//
//  Created by Jone Wang on 2021/3/10.
//

import SwiftUI
import SplatNet3API
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
        VStack {
            if let iconName = iconName {
                FixVectorImage(iconName, tintColor: Color.appLabel)
                    .frame(width: 52, height: 47)
            }
            
            Text("Log in to sync your data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.appLabel)
                .padding(.top, 4)
                .padding(.bottom, 7)
            
            HStack {
                Text("Log in with Nintendo Account")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
            }
            .frame(height: 44)
            .frame(minWidth: 223)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                Task{
                    await viewModel.loginFlow()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor != nil ? backgroundColor : Color.listBackground)
    }

    
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .frame(width: 343, height: 267)
            .previewLayout(.sizeThatFits)
    }
}
