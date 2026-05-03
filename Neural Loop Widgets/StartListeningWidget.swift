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
            Color.white.opacity(0.34),
            Color.white.opacity(0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let border = LinearGradient(
        colors: [
            Color.white.opacity(0.62),
            Color.white.opacity(0.16),
            Color.white.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = Color(red: 0.14, green: 0.49, blue: 0.53)
    static let solidSurface = Color(red: 0.08, green: 0.20, blue: 0.24)
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
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
            VStack(spacing: widgetFamily == .systemSmall ? 6 : (widgetFamily == .systemMedium ? 9 : 12)) {
                if widgetFamily != .systemSmall {
                    header
                }

                shortcutLayout
            }
            .padding(widgetFamily == .systemSmall ? 8 : (widgetFamily == .systemMedium ? 12 : 14))
        }
        .containerBackground(for: .widget) {
            adaptiveWidgetBackground
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            headerBadge
                .frame(width: widgetFamily == .systemLarge ? 34 : 30, height: widgetFamily == .systemLarge ? 34 : 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Neural Loop")
                    .font(.system(size: widgetFamily == .systemLarge ? 14 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextStyle)

                Text("Quick launch")
                    .font(.system(size: widgetFamily == .systemLarge ? 11 : 10, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryTextStyle)
            }

            Spacer(minLength: 0)

            headerTrailingIcon
        }
        .padding(.horizontal, 3)
    }

    private var gridSpacing: CGFloat {
        switch widgetFamily {
        case .systemLarge:
            return 12
        case .systemMedium:
            return 8
        default:
            return 8
        }
    }

    private var tileCornerRadius: CGFloat {
        switch widgetFamily {
        case .systemSmall:
            return 10
        case .systemMedium:
            return 14
        default:
            return 16
        }
    }

    private var usesLiquidGlass: Bool {
        guard !reduceTransparency else { return false }

        switch renderingMode {
        case .fullColor:
            return true
        case .accented, .vibrant:
            return false
        default:
            return true
        }
    }

    private var primaryTextStyle: AnyShapeStyle {
        switch renderingMode {
        case .fullColor:
            return AnyShapeStyle(StartListeningWidgetTheme.tint)
        case .accented, .vibrant:
            return AnyShapeStyle(Color.primary)
        default:
            return AnyShapeStyle(StartListeningWidgetTheme.tint)
        }
    }

    private var secondaryTextStyle: AnyShapeStyle {
        switch renderingMode {
        case .fullColor:
            return AnyShapeStyle(StartListeningWidgetTheme.secondaryText)
        case .accented, .vibrant:
            return AnyShapeStyle(Color.secondary)
        default:
            return AnyShapeStyle(StartListeningWidgetTheme.secondaryText)
        }
    }

    private var systemTileFillOpacity: Double {
        switch renderingMode {
        case .accented:
            return 0.10
        case .vibrant:
            return 0.08
        case .fullColor:
            return 0.10
        default:
            return 0.10
        }
    }

    @ViewBuilder
    private var shortcutLayout: some View {
        if usesLiquidGlass {
            GlassEffectContainer {
                shortcutLayoutContent
            }
        } else {
            shortcutLayoutContent
        }
    }

    @ViewBuilder
    private var shortcutLayoutContent: some View {
        if widgetFamily == .systemSmall {
            compactGrid
        } else if widgetFamily == .systemMedium {
            mediumRow
        } else {
            explicitGrid
        }
    }

    @ViewBuilder
    private var headerBadge: some View {
        let shape = Circle()

        switch renderingMode {
        case .fullColor:
            ZStack {
                if usesLiquidGlass {
                    shape
                        .fill(.clear)
                        .glassEffect(
                            .regular.tint(StartListeningWidgetTheme.accent.opacity(0.28)),
                            in: shape
                        )
                } else {
                    shape
                        .fill(StartListeningWidgetTheme.solidSurface)
                }

                shape
                    .fill(StartListeningWidgetTheme.heroFill)
                    .blendMode(.screen)

                Image(systemName: "sparkles")
                    .font(.system(size: widgetFamily == .systemLarge ? 14 : 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(shape.strokeBorder(StartListeningWidgetTheme.border, lineWidth: 0.6).blendMode(.overlay))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)

        case .accented:
            ZStack {
                shape
                    .fill(Color.primary.opacity(0.10))

                Image(systemName: "sparkles")
                    .font(.system(size: widgetFamily == .systemLarge ? 14 : 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
            }

        case .vibrant:
            ZStack {
                shape
                    .fill(Color.primary.opacity(0.10))

                Image(systemName: "sparkles")
                    .font(.system(size: widgetFamily == .systemLarge ? 14 : 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }

        default:
            ZStack {
                shape
                    .fill(StartListeningWidgetTheme.heroFill)

                Image(systemName: "sparkles")
                    .font(.system(size: widgetFamily == .systemLarge ? 14 : 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(shape.strokeBorder(StartListeningWidgetTheme.border, lineWidth: 0.6))
        }
    }

    @ViewBuilder
    private var headerTrailingIcon: some View {
        let icon = Image(systemName: "arrow.up.right.circle.fill")
            .font(.system(size: widgetFamily == .systemLarge ? 15 : 13, weight: .semibold))

        switch renderingMode {
        case .fullColor:
            icon
                .foregroundStyle(.white.opacity(0.94), StartListeningWidgetTheme.accent)
        case .accented:
            icon
                .foregroundStyle(.primary)
                .widgetAccentable()
        case .vibrant:
            icon
                .foregroundStyle(.primary)
        default:
            icon
                .foregroundStyle(.white.opacity(0.94), StartListeningWidgetTheme.accent)
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
        switch renderingMode {
        case .fullColor:
            fullColorShortcutTile(shortcut)
        case .accented:
            systemShortcutTile(shortcut, accentIcon: true)
        case .vibrant:
            systemShortcutTile(shortcut, accentIcon: false)
        default:
            fullColorShortcutTile(shortcut)
        }
    }

    private func fullColorShortcutTile(_ shortcut: WidgetShortcut) -> some View {
        let cornerRadius = tileCornerRadius

        return VStack(alignment: .center, spacing: widgetFamily == .systemLarge ? 9 : (widgetFamily == .systemMedium ? 5 : 6)) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                shortcut.accentColor.opacity(shortcut.style == .ai ? 0.58 : 0.42),
                                shortcut.accentColor.opacity(shortcut.style == .ai ? 0.22 : 0.16),
                                Color.white.opacity(0.08)
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: shortcut.iconContainerSize(for: widgetFamily)
                        )
                    )
                    .frame(
                        width: shortcut.iconContainerSize(for: widgetFamily),
                        height: shortcut.iconContainerSize(for: widgetFamily)
                    )
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5).blendMode(.overlay))

                Image(systemName: shortcut.systemImage)
                    .font(.system(size: shortcut.iconSize(for: widgetFamily), weight: .semibold))
                    .foregroundStyle(.white)
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
                .foregroundStyle(.white)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.68)

        }
        .frame(maxWidth: .infinity, minHeight: shortcut.minTileHeight(for: widgetFamily), alignment: .center)
        .padding(.horizontal, widgetFamily == .systemSmall ? 8 : (widgetFamily == .systemMedium ? 7 : 12))
        .padding(.vertical, widgetFamily == .systemSmall ? 8 : (widgetFamily == .systemMedium ? 7 : 12))
        .background {
            fullColorTileBackground(shortcut, cornerRadius: cornerRadius)
        }
        .overlay {
            tileSpecularEdge(cornerRadius: cornerRadius, strong: shortcut.style == .ai)
        }
        .shadow(color: .black.opacity(widgetFamily == .systemLarge ? 0.10 : 0.08), radius: 15, x: 0, y: 8)
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }

    private func systemShortcutTile(_ shortcut: WidgetShortcut, accentIcon: Bool) -> some View {
        let cornerRadius = tileCornerRadius
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return VStack(alignment: .center, spacing: widgetFamily == .systemLarge ? 9 : (widgetFamily == .systemMedium ? 5 : 6)) {
            systemShortcutIcon(shortcut, accentIcon: accentIcon)

            Text(shortcut.title)
                .font(.system(size: shortcut.labelSize(for: widgetFamily), weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, minHeight: shortcut.minTileHeight(for: widgetFamily), alignment: .center)
        .padding(.horizontal, widgetFamily == .systemSmall ? 8 : (widgetFamily == .systemMedium ? 7 : 12))
        .padding(.vertical, widgetFamily == .systemSmall ? 8 : (widgetFamily == .systemMedium ? 7 : 12))
        .background {
            shape
                .fill(Color.primary.opacity(systemTileFillOpacity))
        }
        .overlay {
            shape
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.6)
        }
    }

    @ViewBuilder
    private func systemShortcutIcon(_ shortcut: WidgetShortcut, accentIcon: Bool) -> some View {
        let icon = ZStack {
            Circle()
                .fill(Color.primary.opacity(0.10))
                .frame(
                    width: shortcut.iconContainerSize(for: widgetFamily),
                    height: shortcut.iconContainerSize(for: widgetFamily)
                )

            Image(systemName: shortcut.systemImage)
                .font(.system(size: shortcut.iconSize(for: widgetFamily), weight: .semibold))
                .foregroundStyle(.primary)
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

        if accentIcon {
            icon.widgetAccentable()
        } else {
            icon
        }
    }

    @ViewBuilder
    private func fullColorTileBackground(_ shortcut: WidgetShortcut, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            if usesLiquidGlass {
                shape
                    .fill(.clear)
                    .glassEffect(
                        .regular
                            .tint(shortcut.accentColor.opacity(shortcut.style == .ai ? 0.36 : 0.24))
                            .interactive(),
                        in: shape
                    )
            } else {
                shape
                    .fill(StartListeningWidgetTheme.solidSurface)

                shape
                    .fill(shortcut.accentColor)
                    .blendMode(.softLight)
            }

            shape
                .fill(Color.black.opacity(shortcut.style == .ai ? 0.10 : 0.14))
                .blendMode(.multiply)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(shortcut.style == .ai ? 0.24 : 0.18),
                            shortcut.accentColor.opacity(shortcut.style == .ai ? 0.18 : 0.10),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blendMode(.screen)
        }
        .clipShape(shape)
    }

    private func tileSpecularEdge(cornerRadius: CGFloat, strong: Bool) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(strong ? 0.70 : 0.58),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.6
            )
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }

    // MARK: - Background

    @ViewBuilder
    private var adaptiveWidgetBackground: some View {
        switch renderingMode {
        case .fullColor:
            widgetBackground
        case .accented, .vibrant:
            Color.clear
        default:
            widgetBackground
        }
    }

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

#Preview("System Small", as: .systemSmall) {
    StartListeningWidget()
} timeline: {
    StartListeningEntry(date: .now)
}

#Preview("System Medium", as: .systemMedium) {
    StartListeningWidget()
} timeline: {
    StartListeningEntry(date: .now)
}

#Preview("System Large", as: .systemLarge) {
    StartListeningWidget()
} timeline: {
    StartListeningEntry(date: .now)
}

struct StartListeningWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StartListeningWidgetEntryView(entry: StartListeningEntry(date: .now))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.widgetRenderingMode, .accented)
                .previewDisplayName("Small - Accented")

            StartListeningWidgetEntryView(entry: StartListeningEntry(date: .now))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .environment(\.widgetRenderingMode, .accented)
                .previewDisplayName("Medium - Accented")

            StartListeningWidgetEntryView(entry: StartListeningEntry(date: .now))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .environment(\.widgetRenderingMode, .accented)
                .previewDisplayName("Large - Accented")

            StartListeningWidgetEntryView(entry: StartListeningEntry(date: .now))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.widgetRenderingMode, .vibrant)
                .previewDisplayName("Small - Vibrant")
        }
    }
}
