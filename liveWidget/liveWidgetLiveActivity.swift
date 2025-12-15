//
//  liveWidgetLiveActivity.swift
//  liveWidget
//
//  Created by didi on 2025/12/14.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - TaskGroupActivityAttributes

struct TaskGroupActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String?
        var progress: Double?
        var activeTasks: [String]
        var completedTasks: [String]
        var status: TaskStatus
    }
    
    var groupId: String
    var iconName: String
}

enum TaskStatus: String, Codable {
    case inProgress
    case completed
    case failed
}

// MARK: - Legacy Attributes (保留用于兼容)

struct liveWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
    }
    var name: String
}

// MARK: - TaskGroupLiveActivity Widget

struct TaskGroupLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskGroupActivityAttributes.self) { context in
            // Lock screen/banner UI
            TaskGroupLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.iconName)
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let progress = context.state.progress {
                        Text("\(Int(progress * 100))%")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TaskGroupExpandedView(context: context)
                }
            } compactLeading: {
                Image(systemName: context.attributes.iconName)
                    .font(.caption)
            } compactTrailing: {
                if let progress = context.state.progress {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            } minimal: {
                Image(systemName: context.attributes.iconName)
                    .font(.caption2)
            }
            .keylineTint(.blue)
        }
    }
}

// MARK: - Lock Screen View

struct TaskGroupLockScreenView: View {
    let context: ActivityViewContext<TaskGroupActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: context.attributes.iconName)
                    .foregroundColor(.blue)
                Text(context.state.title)
                    .font(.headline)
                Spacer()
                if let progress = context.state.progress {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let subtitle = context.state.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let progress = context.state.progress {
                ProgressView(value: progress)
                    .tint(.blue)
            }
            
            // 显示任务列表
            if !context.state.activeTasks.isEmpty || !context.state.completedTasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(context.state.completedTasks, id: \.self) { task in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(task)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    ForEach(context.state.activeTasks, id: \.self) { task in
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(task)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .activityBackgroundTint(Color(.systemBackground))
        .activitySystemActionForegroundColor(Color.primary)
    }
}

// MARK: - Expanded View (Dynamic Island)

struct TaskGroupExpandedView: View {
    let context: ActivityViewContext<TaskGroupActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(context.state.title)
                .font(.headline)
            
            if let subtitle = context.state.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let progress = context.state.progress {
                ProgressView(value: progress)
                    .tint(.blue)
            }
            
            // 任务列表
            if !context.state.activeTasks.isEmpty || !context.state.completedTasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(context.state.completedTasks, id: \.self) { task in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(task)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    ForEach(context.state.activeTasks, id: \.self) { task in
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(task)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Legacy Widget (保留用于兼容)

struct liveWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: liveWidgetAttributes.self) { context in
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension liveWidgetAttributes {
    fileprivate static var preview: liveWidgetAttributes {
        liveWidgetAttributes(name: "World")
    }
}

extension liveWidgetAttributes.ContentState {
    fileprivate static var smiley: liveWidgetAttributes.ContentState {
        liveWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: liveWidgetAttributes.ContentState {
         liveWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: liveWidgetAttributes.preview) {
   liveWidgetLiveActivity()
} contentStates: {
    liveWidgetAttributes.ContentState.smiley
    liveWidgetAttributes.ContentState.starEyes
}
