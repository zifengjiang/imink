//
//  ContentView.swift
//  imink
//
//  Created by 姜锋 on 5/17/24.
//

import SwiftUI

struct ContentView: View {
    var nso = NSOAuthorization()
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button {
                Task{
                    try await nso.login { sessionToken in
                        print(sessionToken)
                    }
                }
            } label: {
                Text("Login")
            }

        }
        .padding()
    }
}

#Preview {
    ContentView()
}
