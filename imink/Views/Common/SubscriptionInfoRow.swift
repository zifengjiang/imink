//
//  BattleSubscriptionInfoRow.swift
//  imink
//
//  Created by didi on 2025/9/4.
//


import SwiftUI
import SplatDatabase

struct SubscriptionInfoRow: View {
    let subscription: ScheduleSubscription
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // 日程类型图标
                Image(systemName: subscription.scheduleType == .salmonRun ? "fish" : "gamecontroller")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                
                // 日程标题
                Text(subscription.title)
                    .font(.splatoonFont(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
            }
            
            HStack {
                // 时间信息
                Text(formatTimeRange(start: subscription.startTime, end: subscription.endTime))
                    .font(.splatoonFont(size: 10))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // 规则信息（如果有）
                if let rule = subscription.rule {
                    Text(rule)
                        .font(.splatoonFont(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    // 格式化时间范围
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        
        return "\(startString) - \(endString)"
    }
}
