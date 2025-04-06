//
//  MultiSelectionView.swift
//  imink
//
//  Created by 姜锋 on 11/3/24.
//

import SwiftUI

struct MultiSelectionView<Content: View, Title: View>: View {
    @ViewBuilder var title:Title
    @ViewBuilder var content: Content
    let itemSelected: (Int) -> ()
    var columnCount:Int

    @State private var panGesture:UIPanGestureRecognizer?
    @State private var itemLocations:[CGRect] = []
    @State private var properties:SelectionProperties = .init()
    @State private var isSelectionEnabled = true
    @State private var scrollProperties:ScrollProperties = .init()

    init( columnCount:Int, @ViewBuilder title: () -> Title, @ViewBuilder content: () -> Content, itemSelected: @escaping (Int) -> ()){
        self.content = content()
        self.title = title()
        self.columnCount = columnCount
        self.itemSelected = itemSelected
    }

    var body: some View {
        Group(subviews: content) { collection in
            ScrollView(.vertical) {
                VStack(spacing:20){
//                    Text("Grid View")
//                        .font(.title.bold())
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .overlay(alignment: .trailing) {
//                            Button(isSelectionEnabled ?  "Cancel" : "Select"){
//                                isSelectionEnabled.toggle()
//                                if !isSelectionEnabled {
//                                    properties = .init()
//                                }
//                            }
//                            .font(.caption)
//                            .buttonStyle(.borderedProminent)
//                            .buttonBorderShape(.capsule)
//                        }
                    title
                    LazyVGrid(columns: Array(repeating: GridItem(), count: columnCount)) {
                        ForEach(0..<collection.count, id: \.self) { index in
                            collection[index]
                                .overlay(alignment: .topLeading){
                                    if properties.selectedIndices.contains(index) && !properties.toBeDeletedIndices.contains(index){
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.black, .white)
                                            .padding(5)
                                    }
                                }
                                .overlay{
                                    if isSelectionEnabled {
                                        Rectangle()
                                            .foregroundStyle(.clear)
                                            .contentShape(.rect)
                                            .onTapGesture {
                                                if properties.selectedIndices.contains(index){
                                                    properties.selectedIndices.remove(index)
                                                }else{
                                                    properties.selectedIndices.insert(index)
                                                }
                                            }
                                            .transition(.identity)

                                    }
                                }
                                .onGeometryChange(for: CGRect.self) {
                                    $0.frame(in: .global)
                                } action: { newValue in
                                    if index < self.itemLocations.count {
                                        self.itemLocations[index] = newValue
                                    }
                                }
                                .id(index)

                        }
                    }
                }
                .scrollTargetLayout()
            }
            .safeAreaPadding(15)
            .scrollPosition($scrollProperties.position)
            .overlay(alignment: .top, content: {
                ScrollDetectionRegion()
            })
            .overlay(alignment: .bottom, content: {
                ScrollDetectionRegion(false)
            })
            .onChange(of: isSelectionEnabled, { oldValue, newValue in
                panGesture?.isEnabled = newValue
            })
            .onScrollGeometryChange(for: CGFloat.self, of: {
                $0.contentOffset.y + $0.contentInsets.top
            }, action: { oldValue, newValue in
                scrollProperties.currentScrollOffset = newValue
            })
            .onChange(of: scrollProperties.direction, { oldValue, newValue in
                if newValue != .none {
                    guard scrollProperties.time == nil else {return}
                    scrollProperties.time = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: true, block: { _ in
                        if newValue == .up{
                            scrollProperties.manualScrollOffset += 0.03
                        }
                        if newValue == .down{
                            scrollProperties.manualScrollOffset -= 0.03
                        }
                        scrollProperties.position.scrollTo(y: scrollProperties.manualScrollOffset + scrollProperties.currentScrollOffset)
                    })
                    scrollProperties.time?.fire()
                } else{
                    resetTimer()
                }
            })
            .onAppear{
                self.itemLocations = Array(repeating: CGRect.zero, count: collection.count)
            }
            .gesture(
                PanGesture { gesture in
                    if panGesture == nil {
                        panGesture = gesture
                        gesture.isEnabled = isSelectionEnabled
                    }
                    let state = gesture.state

                    if state == .began || state == .changed{
                        onGestureChanged(gesture)
                    } else {
                        onGestureEnded(gesture)
                    }

                }
            )
        }
    }
    @ViewBuilder
    func ScrollDetectionRegion(_ isTop: Bool = true) -> some View {
        Rectangle()
            .foregroundStyle(.clear)
            .frame(height: 100)
            .ignoresSafeArea()
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { newValue in
                if isTop {
                    scrollProperties.topRegion = newValue
                }else{
                    scrollProperties.bottomRegion = newValue
                }
            }

    }

    /// Gesture OnChanged
    private func onGestureChanged(_ gesture: UIPanGestureRecognizer){
        print("onGestureChanged")
        let position = gesture.location(in: gesture.view)
        if let fallingIndex = itemLocations.firstIndex(where: {$0.contains(position)}){
            if properties.start == nil{
                properties.start = fallingIndex
                properties.isDeleteDrag = properties.previousIndices.contains(fallingIndex)
            }

            properties.end = fallingIndex

            if let start = properties.start, let end = properties.end {
                let indices = (start > end ? end...start : start...end).compactMap({$0})
                if properties.isDeleteDrag{
                    properties.toBeDeletedIndices = properties.previousIndices.intersection(indices)/*.compactMap({$0})*/
                }else{
                    properties.selectedIndices = properties.previousIndices.union(indices)/*.compactMap({$0})*/
                }
            }

            scrollProperties.direction = scrollProperties.topRegion.contains(position) ? .down : scrollProperties.bottomRegion.contains(position) ? .up : .none
        }
    }

    private func _onGestureChanged(_ gesture: UIPanGestureRecognizer) {
        let position = gesture.location(in: gesture.view)

        if let fallingIndex = itemLocations.firstIndex(where: { $0.contains(position) }) {

                // 设置起始位置
            if properties.start == nil {
                properties.start = fallingIndex
            }

            properties.end = fallingIndex

            if let start = properties.start, let end = properties.end {
                    // 生成当前划过的索引范围的集合
                let indices = Set(start > end ? end...start : start...end)

                properties.toBeDeletedIndices = properties.previousIndices.intersection(indices)
                properties.selectedIndices = properties.previousIndices.union(indices)
            }
        }
    }
    /// Gesture OnEnded
    private func onGestureEnded(_ gesture: UIPanGestureRecognizer){
        for index in properties.toBeDeletedIndices {
            properties.selectedIndices.remove(index)
        }
        properties.toBeDeletedIndices = []
        properties.previousIndices = properties.selectedIndices
        properties.start = nil
        properties.end = nil
        let _ = properties.selectedIndices.map{
            itemSelected($0)
        }
        resetTimer()
    }

    private func resetTimer() {
        scrollProperties.manualScrollOffset = 0
        scrollProperties.time?.invalidate()
        scrollProperties.time = nil
        scrollProperties.direction = .none
    }

    struct SelectionProperties{
        var start: Int?
        var end: Int?
        var selectedIndices:Set<Int> = []
        var previousIndices:Set<Int> = []
        var toBeDeletedIndices:Set<Int> = []
        var isDeleteDrag:Bool = false

    }

    struct ScrollProperties {
        var position:ScrollPosition = .init()
        var currentScrollOffset:CGFloat = 0
        var manualScrollOffset:CGFloat = 0
        var time:Timer?
        var direction:ScrollDirection = .none
        var topRegion:CGRect = .zero
        var bottomRegion:CGRect = .zero
    }

    enum ScrollDirection {
        case up
        case down
        case none
    }
}

struct PanGesture: UIGestureRecognizerRepresentable {
    var handle: (UIPanGestureRecognizer) -> ()
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        return UIPanGestureRecognizer()
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {

    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        handle(recognizer)
    }
}

//#Preview {
//    MultiSelectionView(selectedIndices: .constant(Set()),columnCount: 4) {
//        ForEach(0..<150,id: \.self) { _ in
//            RoundedRectangle(cornerRadius: 10)
//                .fill(Color(uiColor: UIColor.random()).gradient)
//                .frame(height:80)
//        }
//    }
//}

extension UIColor {
    static func random() -> UIColor {
        let red = CGFloat.random(in: 0...1)
        let green = CGFloat.random(in: 0...1)
        let blue = CGFloat.random(in: 0...1)
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
