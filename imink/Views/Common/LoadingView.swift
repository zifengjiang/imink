import Foundation
import SwiftUI

struct LoadingView: View {

    let size:CGFloat

    var body: some View {
        VStack(alignment: .center){
            Spacer()
            Image(.squidLoading)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.gray)
            Text("Loading...")
                .font(.splatoonFont(size: size/4))
            Spacer()
        }
    }
}
