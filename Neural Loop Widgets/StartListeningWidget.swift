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
        let entry = StartListeningEntry(date: .now)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 24, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget Entry View

struct StartListeningWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    var entry: StartListeningEntry

    private let shortcuts: [WidgetShortcut] = [
        WidgetShortcut(
            title: "AI",
            systemImage: "waveform",
            destination: URL(string: "neural-loop://ai/listen")!,
            style: .ai
        ),
        WidgetShortcut(
            title: "Tasks",
            systemImage: "checklist",
            destination: URL(string: "neural-loop://tasks")!,
            style: .standard
        ),
        WidgetShortcut(
            title: "Calendar",
            systemImage: "calendar",
            destination: URL(string: "neural-loop://calendar")!,
            style: .standard
        ),
        WidgetShortcut(
            title: "Workout",
            systemImage: "figure.strengthtraining.traditional",
            destination: URL(string: "neural-loop://fitness")!,
            style: .standard
        )
    ]

    var body: some View {
        ZStack {
            widgetBackground

            VStack(spacing: widgetFamily == .systemSmall ? 0 : 12) {
                if widgetFamily != .systemSmall {
                    header
                }

                if widgetFamily == .systemSmall {
                    compactGrid
                } else if widgetFamily == .systemMedium {
                    mediumRow
                } else {
                    explicitGrid
                }
            }
            .padding(widgetFamily == .systemSmall ? 8 : 14)
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: widgetFamily == .systemLarge ? 13 : 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            Text("Neural Loop")
                .font(.system(size: widgetFamily == .systemLarge ? 13 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 0)
        }
    }

    private var gridSpacing: CGFloat {
        switch widgetFamily {
        case .systemLarge:
            return 12
        case .systemMedium:
            return 10
        default:
            return 6
        }
    }

    private var compactGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: gridSpacing),
                GridItem(.flexible(), spacing: gridSpacing)
            ],
            spacing: gridSpacing
        ) {
            ForEach(shortcuts) { shortcut in
                Link(destination: shortcut.destination) {
                    shortcutTile(shortcut)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var mediumRow: some View {
        HStack(spacing: gridSpacing) {
            ForEach(shortcuts) { shortcut in
                shortcutLink(shortcut)
            }
        }
    }

    private var explicitGrid: some View {
        VStack(spacing: gridSpacing) {
            HStack(spacing: gridSpacing) {
                shortcutLink(shortcuts[0])
                shortcutLink(shortcuts[1])
            }
            HStack(spacing: gridSpacing) {
                shortcutLink(shortcuts[2])
                shortcutLink(shortcuts[3])
            }
        }
    }

    private func shortcutLink(_ shortcut: WidgetShortcut) -> some View {
        Link(destination: shortcut.destination) {
            shortcutTile(shortcut)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shortcutTile(_ shortcut: WidgetShortcut) -> some View {
        let cornerRadius: CGFloat = widgetFamily == .systemSmall ? 18 : (widgetFamily == .systemMedium ? 18 : 22)

        VStack(spacing: widgetFamily == .systemLarge ? 10 : (widgetFamily == .systemMedium ? 5 : 7)) {
            Image(systemName: shortcut.systemImage)
                .font(.system(size: shortcut.iconSize(for: widgetFamily), weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(shortcut.title)
                .font(.system(size: shortcut.labelSize(for: widgetFamily), weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: shortcut.minTileHeight(for: widgetFamily), alignment: .center)
        .padding(.horizontal, widgetFamily == .systemSmall ? 7 : (widgetFamily == .systemMedium ? 8 : 10))
        .padding(.vertical, widgetFamily == .systemSmall ? 7 : (widgetFamily == .systemMedium ? 8 : 10))
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(shortcut.background(for: widgetFamily))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(shortcut.style == .ai ? 0.18 : 0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(shortcut.style == .ai ? 0.18 : 0.12), radius: 6, x: 0, y: 3)
    }

    // MARK: - Background

    private var widgetBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.78, blue: 0.88),
                    Color(red: 0.35, green: 0.82, blue: 0.75),
                    Color(red: 0.90, green: 0.78, blue: 0.35),
                ],
                startPoint: .leading,
                endPoint: .topTrailing
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.55, green: 0.38, blue: 0.88).opacity(0.7),
                    Color(red: 0.72, green: 0.40, blue: 0.75).opacity(0.5),
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear,
                ],
                center: .center,
                startRadius: 10,
                endRadius: 120
            )
        }
    }
}

private struct WidgetShortcut: Identifiable {
    enum Style {
        case ai
        case standard
    }

    let id = UUID()
    let title: String
    let systemImage: String
    let destination: URL
    let style: Style

    func background(for family: WidgetFamily) -> some ShapeStyle {
        switch style {
        case .ai:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.58, blue: 0.72),
                        Color(red: 0.09, green: 0.43, blue: 0.55),
                        Color(red: 0.14, green: 0.67, blue: 0.80),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .standard:
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    func iconSize(for family: WidgetFamily) -> CGFloat {
        switch (style, family) {
        case (.ai, .systemLarge):
            return 26
        case (.ai, .systemMedium):
            return 20
        case (.ai, _):
            return 18
        case (.standard, .systemLarge):
            return 24
        case (.standard, .systemMedium):
            return 18
        case (.standard, _):
            return 17
        }
    }

    func labelSize(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemLarge:
            return 14
        case .systemMedium:
            return 11
        default:
            return 9
        }
    }

    func minTileHeight(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemLarge:
            return 88
        case .systemMedium:
            return 66
        default:
            return 46
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
        .configurationDisplayName("Neural Loop")
        .description("Quick access to AI, tasks, calendar, and workout.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StartListeningWidget()
} timeline: {
    StartListeningEntry(date: .now)
}

#Preview(as: .systemMedium) {
    StartListeningWidget()
} timeline: {
    StartListeningEntry(date: .now)
}

#Preview(as: .systemLarge) {
    StartListeningWidget()
} timeline: {
    StartListeningEntry(date: .now)
}
