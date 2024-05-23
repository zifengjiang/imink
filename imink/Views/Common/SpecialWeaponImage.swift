import SwiftUI

struct SpecialWeaponImage: View {
    var imageName: String
    var color: Color = Color.specialWeaponDefault
    var size: CGFloat = 12
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .mask {
                Image("\(imageName)00")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size,height: size)
                    .colorMultiply(.black)
            }
            .overlay {
                Image("\(imageName)01")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size,height: size)
            }
    }
}

//#Preview {
//    SpecialWeaponImage()
//}
