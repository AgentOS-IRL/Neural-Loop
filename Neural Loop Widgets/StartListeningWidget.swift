//
//  StartListeningWidget.swift
//  Neural Loop Widgets
//
//  Created by Codex on 28/04/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct StartListeningEntry: TimelineEntry {
    let date: Date
}

struct StartListeningProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartListeningEntry {
        StartListeningEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (StartListeningEntry) -> Void) {
        completion(StartListeningEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StartListeningEntry>) -> Void) {
        // Static widget — refresh once a day is fine.
        let entry = StartListeningEntry(date: .now)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 24, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget Entry View

struct StartListeningWidgetEntryView: View {
    var entry: StartListeningEntry

    var body: some View {
        ZStack {
            VStack(spacing: 0) {

                Spacer()

                // -- Microphone icon --
                Image(systemName: "waveform")
                    .font(.system(size: 100, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                

                        Text(" Neural Loop")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))

                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
        .widgetURL(URL(string: "neural-loop://ai/listen"))
    }

    // MARK: - Background
    private var widgetBackground: some View {
        ZStack {
            // Soft mesh-style gradient: cyan/teal left → yellow/orange top-right → violet bottom-right
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.78, blue: 0.88),   // teal
                    Color(red: 0.35, green: 0.82, blue: 0.75),   // mint
                    Color(red: 0.90, green: 0.78, blue: 0.35),   // warm yellow
                ],
                startPoint: .leading,
                endPoint: .topTrailing
            )

            // Violet/pink wash on the bottom half
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.55, green: 0.38, blue: 0.88).opacity(0.7),  // violet
                    Color(red: 0.72, green: 0.40, blue: 0.75).opacity(0.5),  // pink
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )

            // Subtle centre glow
            RadialGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear,
                ],
                center: .center,
                startRadius: 10,
                endRadius: 100
            )
        }
    }
}


// MARK: - Widget Configuration

struct StartListeningWidget: Widget {
    let kind: String = "StartListeningWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StartListeningProvider()) { entry in
            StartListeningWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Start Listening")
        .description("Open Neural Loop and start voice capture instantly.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StartListeningWidget()
} timeline: {
    StartListeningEntry(date: .now)
}
