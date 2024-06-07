import SwiftUI

struct RightCardView: View {
    var body: some View {
        HStack{
            ForEach(0..<2, id: \.self){_ in
                VStack{
                    HStack{
                        Image(.egg)
                        Image(.golden)
                        Image(.jobShiftCardDead)
                        Image(.jobShiftCardHelp)
                    }
                }
                .frame(width: 530/3, height: 230/3)
                .padding([.top,.bottom],5)
                .background(Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxHeight: .infinity,alignment: .top)
        .padding()
    }
}

#Preview {
    RightCardView()
}
