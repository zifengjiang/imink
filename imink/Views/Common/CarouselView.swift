    //
    //  Carousel.swift
    //  imink
    //
    //  Created by 姜锋 on 10/24/24.
    //

import Foundation
import SwiftUI
import Combine

struct CarouselView<Content: View>: View {
    @ViewBuilder var content: Content

    @Binding var activeIndex: Int
    @State private var scrollPosition: Int?
    @State private var isScrolling = false
    @State private var offsetBasedPosition: Int = 0
    @State private var isSettled = false
    @GestureState private var isHoldingScreen = false
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher>

    @State private var autoScrollDuration: CGFloat

    init(activeIndex:Binding<Int>, autoScrollDuration: CGFloat, @ViewBuilder content: () -> Content) {
        self.content = content()
        _autoScrollDuration = State(initialValue: autoScrollDuration)
        _timer = State(initialValue: Timer.publish(every: autoScrollDuration, on: .main, in: .default).autoconnect())
        self._activeIndex = activeIndex
    }


    var body: some View {
        GeometryReader {
            let size = $0.size
            Group(subviews: content) { collection in
                ScrollView(.horizontal){
                    LazyHStack(spacing: 0){

                        if let lastItem = collection.last {
                            lastItem
                                .frame(width: size.width,height: size.height)
                                .id(-1)

                        }
                        ForEach(0..<collection.count, id: \.self) { index in
                            collection[index]
                                .frame(width: size.width,height: size.height)
                                .id(index)
                                
                        }
                        if let firstItem = collection.first {
                            firstItem
                                .frame(width: size.width,height: size.height)
                                .id(collection.count)

                        }

                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $scrollPosition)
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .onScrollPhaseChange { oldPhase, newPhase in
                    isScrolling = newPhase.isScrolling

                    if !isScrolling && scrollPosition == collection.count && !isHoldingScreen{
                        scrollPosition=0
                    }

                    if !isScrolling && scrollPosition == -1{
                        scrollPosition=collection.count-1
                    }
                }
                .simultaneousGesture(DragGesture(minimumDistance: 0).updating($isHoldingScreen, body: { _, out, _ in
                    out = true
                }))
                .onChange(of: isHoldingScreen) { oldValue, newValue in
                    if newValue{
                        timer.upstream.connect().cancel()
                    } else{
                        if isSettled && scrollPosition != offsetBasedPosition{
                            scrollPosition = offsetBasedPosition
                        }
                        timer = Timer.publish(every: self.autoScrollDuration, on: .main, in: .default).autoconnect()
                    }
                }
                .onChange(of: scrollPosition, { oldValue, newValue in
                    if let newValue {
                        activeIndex = max(min(newValue, collection.count-1),0)
                    }
                })
                .onReceive(timer) { _ in
                    guard !isHoldingScreen && !isScrolling else { return }
                    let nextIndex = (scrollPosition ?? 0) + 1
                    withAnimation(.snappy(duration: 0.25, extraBounce: 0)){
                        scrollPosition = (nextIndex == collection.count + 1) ? 0 : nextIndex
                    }
                }
                .onChange(of: activeIndex, { oldValue, newValue in
                    withAnimation(.snappy(duration: 0.25, extraBounce: 0)){
                        scrollPosition = newValue
                    }
                })
                .onScrollGeometryChange(for: CGFloat.self) {
                    $0.contentOffset.x
                } action: { oldValue, newValue in
                    isSettled = size.width > 0 ? (Int(newValue) % Int(size.width) == 0) : false
                    let index = size.width > 0 ? Int((newValue / size.width).rounded() - 1) : 0
                    offsetBasedPosition = index
                    if isSettled && (scrollPosition != index || index == collection.count) && !isScrolling && !isHoldingScreen {
                        scrollPosition = index == collection.count ? 0 : index
                    }
                }

            }
            .onAppear{
                scrollPosition = 0
            }
        }


    }

}

