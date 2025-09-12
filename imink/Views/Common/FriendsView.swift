//
//  FriendsView.swift
//  imink
//
//  Created by AI Assistant
//

import SwiftUI

struct FriendsView: View {
    @State private var liveFriendsData: [FriendListResult.Data.Friends.Node] = []
    @State private var expandedFriendId: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(liveFriendsData, id: \.id) { friend in
                    FriendView(friend: friend, expandedFriendId: $expandedFriendId)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 100)
        
        .animation(.easeInOut, value: liveFriendsData)
        .task {
            await loadFriends()
        }
    }
    
    private func loadFriends() async {
        isLoading = true
        errorMessage = nil
        
            let client = SN3Client.shared
            
            if let friendListResult = await client.fetchFriendList() {
                let friends = friendListResult.data.friends?.nodes ?? []
                
                await MainActor.run {
                    self.liveFriendsData = friends
                    self.isLoading = false
                }
            }
    
    }
    
}

#Preview {
    FriendsView()
        .padding()
}
