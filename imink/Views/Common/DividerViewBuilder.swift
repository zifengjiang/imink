import SwiftUI

struct DividerViewBuilder<Content: View, Item>: View {
    var items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            content(item)
            if index < items.count - 1 {
                Divider()
            }
        }
    }
}
