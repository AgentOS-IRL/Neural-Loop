//
//  StartListeningWidget.swift
//  Neural Loop Widgets
//
//  Created by Codex on 28/04/2026.
//

import WidgetKit
import SwiftUI

private enum StartListeningWidgetTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.78, blue: 0.88),
            Color(red: 0.35, green: 0.82, blue: 0.75),
            Color(red: 0.90, green: 0.78, blue: 0.35)
        ],
        startPoint: .leading,
        endPoint: .topTrailing
    )

    static let heroFill = LinearGradient(
        colors: [
            Color.white.opacity(0.30),
            Color.white.opacity(0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let border = LinearGradient(
        colors: [
            Color.white.opacity(0.36),
            Color.white.opacity(0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = Color(red: 0.14, green: 0.49, blue: 0.53)
    static let tint = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.82)
    static let glow = Color(red: 0.97, green: 0.77, blue: 0.42)
}

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

    private let primaryShortcuts: [WidgetShortcut] = [
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

    private let largeOnlyShortcuts: [WidgetShortcut] = [
        WidgetShortcut(
            title: "Add Task",
            systemImage: "plus.circle",
            destination: URL(string: "neural-loop://tasks/add")!,
            style: .standard
        ),
        WidgetShortcut(
            title: "Add Note",
            systemImage: "square.and.pencil",
            destination: URL(string: "neural-loop://notes/add")!,
            style: .standard
        )
    ]

    private var displayedShortcuts: [WidgetShortcut] {
        widgetFamily == .systemLarge ? primaryShortcuts + largeOnlyShortcuts : primaryShortcuts
    }

    var body: some View {
        ZStack {
            widgetBackground

            VStack(spacing: widgetFamily == .systemSmall ? 6 : (widgetFamily == .systemMedium ? 9 : 12)) {
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
            .padding(widgetFamily == .systemSmall ? 8 : (widgetFamily == .systemMedium ? 12 : 14))
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(StartListeningWidgetTheme.heroFill)
                    .overlay(Circle().strokeBorder(StartListeningWidgetTheme.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)

                Image(systemName: "sparkles")
                    .font(.system(size: widgetFamily == .systemLarge ? 14 : 12, weight: .semibold))
                    .foregroundStyle(StartListeningWidgetTheme.accent)
            }
            .frame(width: widgetFamily == .systemLarge ? 34 : 30, height: widgetFamily == .systemLarge ? 34 : 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Neural Loop")
                    .font(.system(size: widgetFamily == .systemLarge ? 14 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(StartListeningWidgetTheme.tint)

                Text("Quick launch")
                    .font(.system(size: widgetFamily == .systemLarge ? 11 : 10, weight: .medium, design: .rounded))
                    .foregroundStyle(StartListeningWidgetTheme.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: widgetFamily == .systemLarge ? 15 : 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94), StartListeningWidgetTheme.accent)
        }
        .padding(.horizontal, 3)
    }

    private var gridSpacing: CGFloat {
        switch widgetFamily {
        case .systemLarge:
            return 12
        case .systemMedium:
            return 7
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
            ForEach(displayedShortcuts) { shortcut in
                Link(destination: shortcut.destination) {
                    shortcutTile(shortcut)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var mediumRow: some View {
        HStack(spacing: gridSpacing) {
            ForEach(displayedShortcuts) { shortcut in
                shortcutLink(shortcut)
            }
        }
    }

    private var explicitGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: gridSpacing),
                GridItem(.flexible(), spacing: gridSpacing)
            ],
            spacing: gridSpacing
        ) {
            ForEach(displayedShortcuts) { shortcut in
                shortcutLink(shortcut)
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
        let cornerRadius: CGFloat = widgetFamily == .systemSmall ? 18 : (widgetFamily == .systemMedium ? 20 : 24)

        VStack(alignment: .center, spacing: widgetFamily == .systemLarge ? 9 : (widgetFamily == .systemMedium ? 5 : 6)) {
            ZStack {
                Circle()
                    .fill(shortcut.accentColor.opacity(shortcut.style == .ai ? 0.34 : 0.24))
                    .frame(
                        width: shortcut.iconContainerSize(for: widgetFamily),
                        height: shortcut.iconContainerSize(for: widgetFamily)
                    )

                Image(systemName: shortcut.systemImage)
                    .font(.system(size: shortcut.iconSize(for: widgetFamily), weight: .semibold))
                    .foregroundStyle(shortcut.iconColor)
                    .frame(
                        width: shortcut.iconContainerSize(for: widgetFamily),
                        height: shortcut.iconContainerSize(for: widgetFamily),
                        alignment: .center
                    )
            }
            .frame(
                width: shortcut.iconContainerSize(for: widgetFamily),
                height: shortcut.iconContainerSize(for: widgetFamily),
                alignment: .center
            )

            Text(shortcut.title)
                .font(.system(size: shortcut.labelSize(for: widgetFamily), weight: .semibold, design: .rounded))
                .foregroundStyle(StartListeningWidgetTheme.tint)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.68)

        }
        .frame(maxWidth: .infinity, minHeight: shortcut.minTileHeight(for: widgetFamily), alignment: .center)
        .padding(.horizontal, widgetFamily == .systemSmall ? 8 : (widgetFamily == .systemMedium ? 7 : 12))
        .padding(.vertical, widgetFamily == .systemSmall ? 8 : (widgetFamily == .systemMedium ? 7 : 12))
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(shortcut.tileFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(StartListeningWidgetTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(widgetFamily == .systemLarge ? 0.14 : 0.10), radius: 10, x: 0, y: 5)
    }

    // MARK: - Background

    private var widgetBackground: some View {
        ZStack {
            StartListeningWidgetTheme.background

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.55, green: 0.38, blue: 0.88).opacity(0.58),
                    Color(red: 0.72, green: 0.40, blue: 0.75).opacity(0.40)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    StartListeningWidgetTheme.glow.opacity(0.28),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 18,
                endRadius: 170
            )
            .offset(x: -42, y: -42)
            .blur(radius: 20)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.16),
                    Color.clear
                ],
                center: .center,
                startRadius: 22,
                endRadius: 180
            )
            .offset(x: 30, y: -10)
            .blur(radius: 22)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.black.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
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
    var subtitle: String {
        switch title {
        case "AI":
            return "Listen now"
        case "Tasks":
            return "Review work"
        case "Calendar":
            return "Plan time"
        case "Workout":
            return "Move now"
        case "Add Task":
            return "Capture work"
        case "Add Note":
            return "Save thought"
        default:
            return "Open"
        }
    }

    var tileFill: some ShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [
                    accentColor.opacity(style == .ai ? 0.52 : 0.34),
                    Color.white.opacity(style == .ai ? 0.16 : 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    var accentColor: Color {
        switch title {
        case "AI":
            return Color(red: 0.10, green: 0.58, blue: 0.72)
        case "Tasks":
            return Color(red: 0.35, green: 0.82, blue: 0.75)
        case "Calendar":
            return Color(red: 0.90, green: 0.78, blue: 0.35)
        case "Workout":
            return Color(red: 0.55, green: 0.38, blue: 0.88)
        case "Add Task":
            return Color(red: 0.24, green: 0.70, blue: 0.58)
        case "Add Note":
            return Color(red: 0.72, green: 0.40, blue: 0.75)
        default:
            return StartListeningWidgetTheme.accent
        }
    }

    var iconColor: some ShapeStyle {
        AnyShapeStyle(Color.white.opacity(0.98))
    }

    func iconContainerSize(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemLarge:
            return 40
        case .systemMedium:
            return 30
        default:
            return 34
        }
    }

    func iconSize(for family: WidgetFamily) -> CGFloat {
        switch (style, family) {
        case (.ai, .systemLarge):
            return 22
        case (.ai, .systemMedium):
            return 20
        case (.ai, _):
            return 18
        case (.standard, .systemLarge):
            return 20
        case (.standard, .systemMedium):
            return 18
        case (.standard, _):
            return 17
        }
    }

    func labelSize(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemLarge:
            return 12
        case .systemMedium:
            return 9
        default:
            return 9
        }
    }

    func minTileHeight(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemLarge:
            return 58
        case .systemMedium:
            return 58
        default:
            return 48
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
