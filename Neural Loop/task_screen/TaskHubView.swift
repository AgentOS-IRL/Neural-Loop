//
//  TaskHubView.swift
//  Neural Loop
//
//  Created by Codex on 15/04/2026.
//

import SwiftUI
import Combine

enum TaskHubSection: String, CaseIterable, Identifiable {
    case todo = "To Do"
    case habits = "Habits"

    var id: String { rawValue }
}

enum TaskHubSwipeDirection {
    case left
    case right
}

@MainActor
final class TaskHubNavigationModel: ObservableObject {
    @Published var selectedSection: TaskHubSection = .todo

    func select(_ section: TaskHubSection) {
        selectedSection = section
    }

    func section(afterSwipe direction: TaskHubSwipeDirection) -> TaskHubSection {
        switch (selectedSection, direction) {
        case (.todo, .left):
            return .habits
        case (.habits, .right):
            return .todo
        default:
            return selectedSection
        }
    }

    func handleSwipe(_ direction: TaskHubSwipeDirection) {
        selectedSection = section(afterSwipe: direction)
    }
}

struct TaskHubView: View {
    @StateObject private var navigationModel = TaskHubNavigationModel()

    private let taskHubEdgeSwipeStartThreshold: CGFloat = 32
    private let taskHubSwipeMinimumDistance: CGFloat = 72
    private let taskHubSwipeVerticalTolerance: CGFloat = 48

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    switch navigationModel.selectedSection {
                    case .todo:
                        TodoView(embeddedInTaskHub: true)
                    case .habits:
                        HabitView(embeddedInTaskHub: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(taskHubEdgeSwipeGesture(width: proxy.size.width))
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                TaskHubSectionBar(
                    selectedSection: $navigationModel.selectedSection,
                    selectAction: navigationModel.select
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
    }

    private func taskHubEdgeSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: taskHubSwipeMinimumDistance)
            .onEnded { value in
                guard let direction = taskHubSwipeDirection(for: value, width: width) else { return }

                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    navigationModel.handleSwipe(direction)
                }
            }
    }

    private func taskHubSwipeDirection(for value: DragGesture.Value, width: CGFloat) -> TaskHubSwipeDirection? {
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height
        let absoluteHorizontalDistance = abs(horizontalDistance)

        guard absoluteHorizontalDistance >= taskHubSwipeMinimumDistance else { return nil }
        guard abs(verticalDistance) <= taskHubSwipeVerticalTolerance else { return nil }
        guard absoluteHorizontalDistance > abs(verticalDistance) else { return nil }

        if horizontalDistance > 0 {
            return value.startLocation.x <= taskHubEdgeSwipeStartThreshold ? .right : nil
        }

        let rightEdgeThreshold = max(0, width - taskHubEdgeSwipeStartThreshold)
        return value.startLocation.x >= rightEdgeThreshold ? .left : nil
    }
}

private struct TaskHubSectionBar: View {
    @Binding var selectedSection: TaskHubSection
    let selectAction: (TaskHubSection) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TaskHubSection.allCases) { section in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectAction(section)
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(sectionForeground(isSelected: selectedSection == section))
                        .background {
                            if selectedSection == section {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(sectionFill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(backgroundFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }

    private var backgroundFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.secondarySystemBackground).opacity(0.96))
        }

        return AnyShapeStyle(AppTheme.sectionGradient)
    }

    private var sectionFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.tertiarySystemBackground))
        }

        return AnyShapeStyle(AppTheme.heroGradient)
    }

    private func sectionForeground(isSelected: Bool) -> Color {
        if isSelected {
            return AppTheme.textPrimary
        }

        return AppTheme.textSecondary
    }
}
