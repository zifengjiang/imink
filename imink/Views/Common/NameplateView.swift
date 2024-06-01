//import SwiftUI
//import SplatDatabase
//
//struct NameplateView: View {
//    let player:Player
//
//    var body: some View {
//        GeometryReader { geometry in
//            let geometryHeight = geometry.size.height
//            let geometryWidth = geometry.size.width
//
//            ZStack(alignment: .topLeading) {
//                if let backgroundImageURL = nameplate.background?.image?.url {
//                    KFImage(URL(string: backgroundImageURL))
//                        .resizable()
//                        .aspectRatio(contentMode: .fill)
//                        .frame(width: geometryWidth, height: geometryHeight)
//                        .clipped()
//                        .cornerRadius(geometryWidth*0.02)
//                }
//                
//
//                Text(byName)
//                    .inkFont(.font1, size: geometryWidth * 12/284, relativeTo: .body)
//                    .foregroundColor(textColor)
//                    .padding(.top, geometryWidth * 5/284)
//                    .padding(.leading, geometryWidth * 10/284)
//
//
//                Text(playerName)
//                    .inkFont(.Splatoon2, size: geometryWidth * 26/284, relativeTo: .body)
//                    .foregroundColor(textColor)
//                    .position(x: geometryWidth / 2, y: geometryHeight / 2)
//                
//                if nameplate.badges?.count != 0{
//
//                    VStack {
//                        Spacer()
//                      HStack(spacing:geometryWidth*2/284) {
//                            Spacer()
//
//                            ForEach(nameplate.badges ?? [], id: \.id) { badge in
//                                if let badgeImageUrl = badge.image?.url {
//                                    KFImage(URL(string: badgeImageUrl))
//                                        .resizable()
//                                        .scaledToFit()
//                                        .padding([.trailing,.bottom],1/284)
//                                        .frame(width: geometryHeight * 0.345, height: geometryHeight * 0.345)
//
//                                }
//                            }
//                        }
//                    }
//
//                }
//                
//
//                VStack {
//                    Spacer()
//                    HStack {
//                        Text("#\(nameId)")
//                            .inkFont(.font1, size: geometryWidth*10/284, relativeTo: .body)
//                            .foregroundColor(textColor)
//                            .padding(.leading, geometryWidth * 10/284)
//                            .padding(.bottom, geometryWidth * 5/284)
//
//                        Spacer()
//                    }
//
//                }
//
//            }
//        }
//        .aspectRatio(3.5, contentMode: .fit)
//        .frame(minWidth: 50)
//    }
//}
//
//
//
//
//
//
