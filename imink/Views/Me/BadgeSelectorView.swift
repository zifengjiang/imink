import SwiftUI
import SplatDatabase

// 徽章层级节点
struct BadgeNode: Identifiable {
    let id = UUID()
    let name: String
    let displayName: String // 用于显示的简化名称
    let fullPath: String
    var children: [BadgeNode] = []
    var badges: [ImageMap] = [] // 存储该节点下的所有徽章
    
    var hasChildren: Bool {
        return !children.isEmpty
    }
    
    var hasBadges: Bool {
        return !badges.isEmpty
    }
    
    init(name: String, displayName: String? = nil, fullPath: String, children: [BadgeNode] = [], badges: [ImageMap] = []) {
        self.name = name
        self.displayName = displayName ?? name
        self.fullPath = fullPath
        self.children = children
        self.badges = badges
    }
}

struct BadgeSelectorView: View {
    @ObservedObject var viewModel: NameplateEditorViewModel
    let selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var badgeHierarchy: [BadgeNode] = []
    
    var filteredBadges: [ImageMap] {
        if searchText.isEmpty {
            return viewModel.availableBadges
        } else {
            return viewModel.availableBadges.filter { badge in
                badge.name.localizedCaseInsensitiveContains(searchText) ||
                badge.nameId.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var showHierarchy: Bool {
        return searchText.isEmpty
    }
    
    // 构建徽章层级结构
    func buildBadgeHierarchy() {
        var rootNodes: [String: BadgeNode] = [:]
        var singleBadges: [ImageMap] = []
        
        for badge in viewModel.availableBadges {
            let components = badge.name.components(separatedBy: "_")
            guard components.count > 1 && components[0] == "Badge" else { continue }
            
            // 跳过第一个 "Badge_"
            var pathComponents = Array(components.dropFirst())
            
            // 如果最后一个组件是 Lv 开头的，将其与前一个组件合并
//            if pathComponents.count > 1 && pathComponents.last?.hasPrefix("Lv") == true {
//                let lastComponent = pathComponents.removeLast()
//                let secondLastIndex = pathComponents.count - 1
//                pathComponents[secondLastIndex] = pathComponents[secondLastIndex] + "_" + lastComponent
//            }
            
            // 最多展示三层
            pathComponents = Array(pathComponents.prefix(3))
            
            // 如果只有一层，放到单独的分组中
            if pathComponents.count == 1 {
                singleBadges.append(badge)
            } else {
                insertBadgeIntoHierarchy(
                    badge: badge,
                    pathComponents: pathComponents,
                    currentNodes: &rootNodes,
                    currentPath: ""
                )
            }
        }
        
        // 如果有单层徽章，创建一个特殊的分组
        if !singleBadges.isEmpty {
            rootNodes["其他徽章"] = BadgeNode(
                name: "其他徽章",
                fullPath: "Badge_其他徽章",
                badges: singleBadges.sorted { $0.name < $1.name }
            )
        }
        
        // 优化层级结构：合并只有一个徽章的节点
        let optimizedNodes = rootNodes.mapValues { optimizeNode($0) }
        
        badgeHierarchy = Array(optimizedNodes.values)
            .sorted { $0.name < $1.name }
            .map { sortNodeChildren($0) }
    }
    
    // 递归插入徽章到层级结构中
    func insertBadgeIntoHierarchy(
        badge: ImageMap,
        pathComponents: [String],
        currentNodes: inout [String: BadgeNode],
        currentPath: String
    ) {
        guard !pathComponents.isEmpty else { return }
        
        let component = pathComponents[0]
        let newPath = currentPath.isEmpty ? component : "\(currentPath)_\(component)"
        let fullPath = "Badge_\(newPath)"
        
        if currentNodes[component] == nil {
            currentNodes[component] = BadgeNode(
                name: component,
                fullPath: fullPath
            )
        }
        
        if pathComponents.count == 1 {
            // 这是叶子节点，添加徽章
            currentNodes[component]?.badges.append(badge)
        } else {
            // 继续递归到下一层
            let remainingComponents = Array(pathComponents.dropFirst())
            var childNodes: [String: BadgeNode] = [:]
            
            // 先获取现有的子节点
            for child in currentNodes[component]?.children ?? [] {
                childNodes[child.name] = child
            }
            
            insertBadgeIntoHierarchy(
                badge: badge,
                pathComponents: remainingComponents,
                currentNodes: &childNodes,
                currentPath: newPath
            )
            
            // 更新子节点
            currentNodes[component]?.children = Array(childNodes.values)
        }
    }
    
    // 优化节点：合并只有一个徽章的节点
    func optimizeNode(_ node: BadgeNode) -> BadgeNode {
        var optimizedNode = node
        
        // 递归优化子节点
        optimizedNode.children = node.children.map { optimizeNode($0) }
        
        // 检查是否所有子节点都只有单个徽章且没有子节点
        let singleBadgeChildren = optimizedNode.children.filter { child in
            !child.hasChildren && child.badges.count == 1
        }
        
        // 如果所有子节点都是单徽章节点，将它们合并到当前节点
        if !singleBadgeChildren.isEmpty && singleBadgeChildren.count == optimizedNode.children.count {
            var allBadges = optimizedNode.badges
            for child in singleBadgeChildren {
                allBadges.append(contentsOf: child.badges)
            }
            
            optimizedNode = BadgeNode(
                name: optimizedNode.name,
                displayName: optimizedNode.displayName,
                fullPath: optimizedNode.fullPath,
                children: [],
                badges: allBadges.sorted { $0.name < $1.name }
            )
        }
        // 如果当前节点只有一个子节点，且该子节点只有徽章没有子节点
        else if optimizedNode.children.count == 1 {
            let child = optimizedNode.children[0]
            if !child.hasChildren && child.hasBadges {
                // 合并到当前节点，更新显示名称为合并后的名称
                let combinedDisplayName = "\(optimizedNode.displayName) - \(child.displayName)"
                optimizedNode = BadgeNode(
                    name: optimizedNode.name,
                    displayName: combinedDisplayName,
                    fullPath: optimizedNode.fullPath,
                    children: [],
                    badges: optimizedNode.badges + child.badges
                )
            }
        }
        
        return optimizedNode
    }
    
    // 递归排序节点的子节点
    func sortNodeChildren(_ node: BadgeNode) -> BadgeNode {
        var sortedNode = node
        sortedNode.children = node.children
            .sorted { $0.name < $1.name }
            .map { sortNodeChildren($0) }
        return sortedNode
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索栏
                SearchBar(text: $searchText)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            // 移除徽章选项
                            Button {
                                viewModel.setBadge(at: selectedIndex, badge: nil)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.system(size: 16))
                                        }
                                    
                                    Text("移除徽章")
                                        .font(.body)
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            
                            if showHierarchy {
                                // 层级展示
                                ForEach(badgeHierarchy) { node in
                                    BadgeNodeView(
                                        node: node,
                                        selectedIndex: selectedIndex,
                                        viewModel: viewModel,
                                        dismiss: dismiss
                                    )
                                }
                                .padding(.horizontal)
                            } else {
                                // 搜索结果的网格展示
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 15) {
                                    ForEach(filteredBadges, id: \.nameId) { badge in
                                        Button {
                                            viewModel.setBadge(at: selectedIndex, badge: badge.name)
                                            dismiss()
                                        } label: {
                                            VStack(spacing: 8) {
                                                Image(badge.name)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 60, height: 60)
                                                    .background(Color(.systemGray6))
                                                    .cornerRadius(8)
                                                    .overlay {
                                                        // 如果当前已选中，显示选中状态
                                                        if viewModel.selectedBadges[selectedIndex] == badge.name {
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .stroke(Color.accentColor, lineWidth: 3)
                                                        }
                                                    }
                                                
                                                Text(badge.name.replacingOccurrences(of: "Badge_", with: ""))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择徽章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                buildBadgeHierarchy()
            }
            .onChange(of: viewModel.availableBadges) { _ in
                buildBadgeHierarchy()
            }
        }
    }
}

// 递归的徽章节点视图
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

// 徽章网格视图
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

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索徽章...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    BadgeSelectorView(viewModel: NameplateEditorViewModel(), selectedIndex: 0)
}
