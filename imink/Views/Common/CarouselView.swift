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
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher>?
    @State private var delayTimer: Timer?

    @State private var autoScrollDuration: CGFloat
    @State private var userInactivityDelay: CGFloat = 3.0 // 用户不活动3秒后开始自动滚动

    init(activeIndex:Binding<Int>, autoScrollDuration: CGFloat, userInactivityDelay: CGFloat = 3.0, @ViewBuilder content: () -> Content) {
        self.content = content()
        _autoScrollDuration = State(initialValue: autoScrollDuration)
        _userInactivityDelay = State(initialValue: userInactivityDelay)
        _timer = State(initialValue: nil)
        self._activeIndex = activeIndex
    }


    // 开始延迟定时器
    private func startDelayTimer() {
        stopAllTimers()
        delayTimer = Timer.scheduledTimer(withTimeInterval: userInactivityDelay, repeats: false) { _ in
            startAutoScrollTimer()
        }
    }
    
    // 开始自动滚动定时器
    private func startAutoScrollTimer() {
        timer = Timer.publish(every: autoScrollDuration, on: .main, in: .default).autoconnect()
    }
    
    // 停止所有定时器
    private func stopAllTimers() {
        delayTimer?.invalidate()
        delayTimer = nil
        timer?.upstream.connect().cancel()
        timer = nil
    }

    var body: some View {
        GeometryReader {
            let size = $0.size
            Group(subviews: content) { collection in
                ScrollView(.horizontal){
                    HStack(spacing: 0){

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
                    if newValue {
                        // 用户开始触摸，停止所有定时器
                        stopAllTimers()
                    } else {
                        // 用户停止触摸，开始延迟定时器
                        if isSettled && scrollPosition != offsetBasedPosition {
                            scrollPosition = offsetBasedPosition
                        }
                        startDelayTimer()
                    }
                }
                .onChange(of: scrollPosition, { oldValue, newValue in
                    if let newValue {
                        activeIndex = max(min(newValue, collection.count-1),0)
                    }
                })
                .onReceive(timer ?? Timer.publish(every: 1, on: .main, in: .default).autoconnect()) { _ in
                    guard timer != nil && !isHoldingScreen && !isScrolling else { return }
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
                // 启动初始延迟定时器
                startDelayTimer()
            }
            .onDisappear {
                // 清理定时器
                stopAllTimers()
            }
        }
    }

}

