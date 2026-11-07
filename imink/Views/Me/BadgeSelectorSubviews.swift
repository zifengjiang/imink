import SwiftUI
import SplatDatabase

struct BadgeNodeView: View {
    let node: BadgeNode
    let selectedIndex: Int
    @ObservedObject var viewModel: NameplateEditorViewModel
    let dismiss: DismissAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if node.hasChildren {
                // 有子节点，使用 DisclosureGroup
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 5) {
                        // 显示当前节点的徽章（如果有）
                        if node.hasBadges {
                            BadgeGridView(
                                badges: node.badges,
                                selectedIndex: selectedIndex,
                                viewModel: viewModel,
                                dismiss: dismiss,
                                parentPath: node.fullPath
                            )
                        }
                        
                        // 递归显示子节点
                        ForEach(node.children) { childNode in
                            BadgeNodeView(
                                node: childNode,
                                selectedIndex: selectedIndex,
                                viewModel: viewModel,
                                dismiss: dismiss
                            )
                            .padding(.leading, 10)
                        }
                    }
                } label: {
                    HStack {
                        Text(node.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // 显示徽章数量
                        let totalBadges = countTotalBadges(in: node)
                        if totalBadges > 0 {
                            Text("\(totalBadges)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(10)
                        }
                    }
                }
            } else if node.hasBadges {
                // 只有徽章，没有子节点
                VStack(alignment: .leading, spacing: 8) {
                    HStack{
                        Text(node.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(node.badges.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(10)
                    }
                    
                    BadgeGridView(
                        badges: node.badges,
                        selectedIndex: selectedIndex,
                        viewModel: viewModel,
                        dismiss: dismiss,
                        parentPath: node.fullPath
                    )
                }
            }
        }
    }
    
    // 递归计算节点下的总徽章数
    func countTotalBadges(in node: BadgeNode) -> Int {
        var count = node.badges.count
        for child in node.children {
            count += countTotalBadges(in: child)
        }
        return count
    }
}

struct BadgeGridView: View {
    let badges: [ImageMap]
    let selectedIndex: Int
    @ObservedObject var viewModel: NameplateEditorViewModel
    let dismiss: DismissAction
    let parentPath: String? // 父级路径，用于计算显示名称
    
    init(badges: [ImageMap], selectedIndex: Int, viewModel: NameplateEditorViewModel, dismiss: DismissAction, parentPath: String? = nil) {
        self.badges = badges
        self.selectedIndex = selectedIndex
        self.viewModel = viewModel
        self.dismiss = dismiss
        self.parentPath = parentPath
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
            ForEach(badges, id: \.nameId) { badge in
                Button {
                    viewModel.setBadge(at: selectedIndex, badge: badge.name)
                    dismiss()
                } label: {
                    VStack(spacing: 4) {
                        Image(badge.name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                            .overlay {
                                // 如果当前已选中，显示选中状态
                                if viewModel.selectedBadges[selectedIndex] == badge.name {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.accentColor, lineWidth: 2)
                                }
                            }
                        
                        Text(getDisplayName(for: badge))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 5)
    }
    
    // 获取徽章的显示名称（只显示最后一部分）
    func getDisplayName(for badge: ImageMap) -> String {
        let fullName = badge.name.replacingOccurrences(of: "Badge_", with: "")
        let components = fullName.components(separatedBy: "_")
        
        // 返回最后一个组件作为显示名称
        return components.last ?? fullName
    }
}
