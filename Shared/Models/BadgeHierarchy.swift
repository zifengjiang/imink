import Foundation
import SplatDatabase

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

/// 把徽章按名称路径构建成层级结构。
///
/// 徽章名称形如 `Badge_<类别>_<子类>_<LvN>`，最多展示三层；
/// 只有一个徽章的子节点会合并到父节点，减少无意义的下钻层级。
enum BadgeHierarchy {
    /// 单层徽章归入的分组名称。
    static let singleLevelGroupName = "其他徽章"

    static func build(from badges: [ImageMap]) -> [BadgeNode] {
        var rootNodes: [String: BadgeNode] = [:]
        var singleBadges: [ImageMap] = []

        for badge in badges {
            let components = badge.name.components(separatedBy: "_")
            guard components.count > 1, components[0] == "Badge" else { continue }

            let pathComponents = Array(components.dropFirst().prefix(3))
            if pathComponents.count == 1 {
                singleBadges.append(badge)
            } else {
                insert(badge: badge, pathComponents: pathComponents, nodes: &rootNodes, parentPath: "")
            }
        }

        if !singleBadges.isEmpty {
            rootNodes[singleLevelGroupName] = BadgeNode(
                name: singleLevelGroupName,
                fullPath: "Badge_\(singleLevelGroupName)",
                badges: singleBadges.sorted { $0.name < $1.name }
            )
        }

        return rootNodes.values
            .map { optimize($0) }
            .sorted { $0.name < $1.name }
            .map { sortChildren($0) }
    }

    // MARK: - 内部

    private static func insert(
        badge: ImageMap,
        pathComponents: [String],
        nodes: inout [String: BadgeNode],
        parentPath: String
    ) {
        guard let component = pathComponents.first else { return }

        let path = parentPath.isEmpty ? component : "\(parentPath)_\(component)"
        if nodes[component] == nil {
            nodes[component] = BadgeNode(name: component, fullPath: "Badge_\(path)")
        }

        if pathComponents.count == 1 {
            nodes[component]?.badges.append(badge)
            return
        }

        var childNodes = Dictionary(uniqueKeysWithValues: (nodes[component]?.children ?? []).map { ($0.name, $0) })
        insert(
            badge: badge,
            pathComponents: Array(pathComponents.dropFirst()),
            nodes: &childNodes,
            parentPath: path
        )
        nodes[component]?.children = Array(childNodes.values)
    }

    /// 合并只含单个徽章的子节点，避免点到最后一层只有一个徽章。
    private static func optimize(_ node: BadgeNode) -> BadgeNode {
        var result = node
        result.children = node.children.map { optimize($0) }

        let singleBadgeChildren = result.children.filter { !$0.hasChildren && $0.badges.count == 1 }
        if !singleBadgeChildren.isEmpty, singleBadgeChildren.count == result.children.count {
            let badges = result.badges + singleBadgeChildren.flatMap(\.badges)
            return BadgeNode(
                name: result.name,
                displayName: result.displayName,
                fullPath: result.fullPath,
                badges: badges.sorted { $0.name < $1.name }
            )
        }

        if result.children.count == 1 {
            let child = result.children[0]
            if !child.hasChildren, child.hasBadges {
                return BadgeNode(
                    name: result.name,
                    displayName: "\(result.displayName) - \(child.displayName)",
                    fullPath: result.fullPath,
                    badges: result.badges + child.badges
                )
            }
        }

        return result
    }

    private static func sortChildren(_ node: BadgeNode) -> BadgeNode {
        var result = node
        result.children = node.children
            .sorted { $0.name < $1.name }
            .map { sortChildren($0) }
        return result
    }
}
