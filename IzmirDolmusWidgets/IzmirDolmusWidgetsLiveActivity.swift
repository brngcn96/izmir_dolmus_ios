//
//  IzmirDolmusWidgetsLiveActivity.swift
//  IzmirDolmusWidgets
//
//  Created by Baran Göcen on 29.10.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct IzmirDolmusWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct IzmirDolmusWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IzmirDolmusWidgetsAttributes.self) { context in
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

extension IzmirDolmusWidgetsAttributes {
    fileprivate static var preview: IzmirDolmusWidgetsAttributes {
        IzmirDolmusWidgetsAttributes(name: "World")
    }
}

extension IzmirDolmusWidgetsAttributes.ContentState {
    fileprivate static var smiley: IzmirDolmusWidgetsAttributes.ContentState {
        IzmirDolmusWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: IzmirDolmusWidgetsAttributes.ContentState {
         IzmirDolmusWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: IzmirDolmusWidgetsAttributes.preview) {
   IzmirDolmusWidgetsLiveActivity()
} contentStates: {
    IzmirDolmusWidgetsAttributes.ContentState.smiley
    IzmirDolmusWidgetsAttributes.ContentState.starEyes
}
