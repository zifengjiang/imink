import SwiftUI

struct EditableNameplateView: View {
    @ObservedObject var viewModel: NameplateEditorViewModel
    @Binding var showingBadgeSelector: Bool
    @Binding var showingBackgroundSelector: Bool
    @Binding var selectedBadgeIndex: Int
    
    var body: some View {
        GeometryReader { geometry in
            let geometryHeight = geometry.size.height
            let geometryWidth = geometry.size.width

            ZStack(alignment: .topLeading) {
                // 背景图片 - 不可点击，只作为背景
                Image(viewModel.selectedBackground)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometryWidth, height: geometryHeight)
                    .clipped()
                    .cornerRadius(geometryWidth*0.02)
                
                // 背景点击区域 - 覆盖中央区域
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            print("Background tapped")
                            showingBackgroundSelector = true
                        } label: {
                            Color.clear
                                .frame(width: geometryWidth * 0.5, height: geometryHeight * 0.4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    Spacer()
                }
                
                // 称号文本
                VStack(alignment: .leading) {
                    Text(viewModel.customByname)
                        .font(.splatoonFont(size: geometryWidth * 12/284))
                        .foregroundColor(viewModel.selectedTextColor)
                        .padding(.top, geometryWidth * 5/284)
                        .padding(.leading, geometryWidth * 10/284)
                    Spacer()
                }

                // 玩家名称 - 居中
                Text(viewModel.customName)
                    .font(.splatoonFont1(size: geometryWidth * 26/284))
                    .foregroundColor(viewModel.selectedTextColor)
                    .position(x: geometryWidth / 2, y: geometryHeight / 2)

                // 徽章区域
                VStack {
                    Spacer()
                    HStack(spacing: geometryWidth*2/284) {
                        Spacer()
                        
                        ForEach(0..<3, id: \.self) { index in
                            BadgeSlot(
                                badge: viewModel.selectedBadges[index],
                                geometryHeight: geometryHeight,
                                onTap: {
                                    print("Badge slot \(index) tapped")
                                    selectedBadgeIndex = index
                                    showingBadgeSelector = true
                                }
                            )
                        }
                    }
                }

                // 玩家ID
                VStack {
                    Spacer()
                    HStack {
                        Text("#\(viewModel.customNameId)")
                            .font(.splatoonFont(size: geometryWidth*10/284))
                            .foregroundColor(viewModel.selectedTextColor)
                            .padding(.leading, geometryWidth * 10/284)
                            .padding(.bottom, geometryWidth * 5/284)

                        Spacer()
                    }
                }
            }
        }
        .aspectRatio(3.5, contentMode: .fit)
        .frame(minWidth: 200, maxWidth: 400)
    }
}

struct BadgeSlot: View {
    let badge: String?
    let geometryHeight: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Group {
                if let badge = badge {
                    Image(badge)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometryHeight * 0.345, height: geometryHeight * 0.345)
                } else {
                    // 空徽章槽 - 显示虚线框
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .frame(width: geometryHeight * 0.345, height: geometryHeight * 0.345)
                        .overlay {
                            Image(systemName: "plus")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: geometryHeight * 0.15))
                        }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding([.trailing,.bottom], 1/284)
    }
}

#Preview {
    EditableNameplateView(
        viewModel: NameplateEditorViewModel(),
        showingBadgeSelector: .constant(false),
        showingBackgroundSelector: .constant(false),
        selectedBadgeIndex: .constant(0)
    )
    .frame(height: 120)
    .padding()
}
