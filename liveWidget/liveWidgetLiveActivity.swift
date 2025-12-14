//
//  liveWidgetLiveActivity.swift
//  liveWidget
//
//  Created by didi on 2025/12/14.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct liveWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct liveWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: liveWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
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
