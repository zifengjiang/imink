//
//  FriendView.swift
//  imink
//
//  Created by AI Assistant
//

import SwiftUI
import Kingfisher

struct FriendView: View {
    let friend: FriendListResult.Data.Friends.Node
    @Binding var expandedFriendId: String?
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 55, height: 55)
                    .overlay(
                        KFImage(URL(string: friend.userIcon?.url ?? ""))
                            .placeholder {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                            }
                            .resizable()
                            .scaledToFit()
//                            .fade(duration: 0.25)
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(getFriendColor(friend: friend), lineWidth: 1.2)
                    )
                    .shadow(radius: 3)
                
                // 状态图标
                if friend.onlineState != "OFFLINE" && friend.onlineState != "ONLINE" {
                    getStateIcon(friend: friend)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .offset(x: 12, y: 12)
                        .background(Circle().fill(Color.white).frame(width: 12, height: 12))
                }
            }
            
            // 展开显示昵称
            if expandedFriendId == friend.id {
                Text(friend.nickname)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .frame(maxWidth: 35)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: 60, height: expandedFriendId == friend.id ? 90 : 70)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedFriendId = (expandedFriendId == friend.id) ? nil : friend.id
            }
        }
    }
}

#Preview {
    @State var expandedId: String? = "sample"
    
    let sampleFriend = FriendListResult.Data.Friends.Node(
        id: "sample",
        coopRule: nil,
        isLocked: false,
        isVcEnabled: true,
        nickname: "TestFriend",
        onlineState: "VS_MODE_FIGHTING",
        playerName: "Player#1234",
        userIcon: FriendListResult.Data.Friends.Node.UserIcon(
            height: 256,
            url: "https://example.com/avatar.png",
            width: 256
        ),
        vsMode: VsMode(id: "VnNNb2RlLTE=", mode: "regular"),
        isFavorite: true
    )
    
    return FriendView(friend: sampleFriend, expandedFriendId: $expandedId)
        .padding()
}
