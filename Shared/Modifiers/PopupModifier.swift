//
//  PopupModifier.swift
//  imink
//
//  Created by Jone Wang on 2021/4/29.
//

import SwiftUI

struct Popup<T: View>: ViewModifier {
    let popup: T
    var isPresented: Bool
    let onDismiss: () -> Void
    
    init(isPresented: Bool, onDismiss: @escaping () -> Void, @ViewBuilder content: () -> T) {
        self.isPresented = isPresented
        self.popup = content()
        self.onDismiss = onDismiss
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                withAnimation{
                    ZStack {
                        if isPresented {
                            Rectangle()
                                .foregroundColor(.black.opacity(0.5))
                                .transition(.opacity)
                                .onTapGesture {
                                    onDismiss()
                                }
                        }

                        makePopupContent()
                    }
                }
            )
    }
    
    @ViewBuilder private func makePopupContent() -> some View {
        GeometryReader { geometry in
            if isPresented {
                withAnimation{
                    popup
                        .transition(.offset(x: 0, y: geometry.size.height))
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                }

            }
        }
    }
}

fileprivate extension Animation {
    
    static func popupEaseOut() -> Animation {
        .timingCurve(0.25, 0.95, 0.15, 1, duration: 0.4)
    }
}
