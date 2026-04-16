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

@MainActor
final class TaskHubNavigationModel: ObservableObject {
    @Published var selectedSection: TaskHubSection = .todo

    func select(_ section: TaskHubSection) {
        selectedSection = section
    }
}

struct TaskHubView: View {
    @StateObject private var navigationModel = TaskHubNavigationModel()

    var body: some View {
        NavigationStack {
            ZStack {
                switch navigationModel.selectedSection {
                case .todo:
                    TodoView(embeddedInTaskHub: true)
                case .habits:
                    HabitView(embeddedInTaskHub: true)
                }
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
                        .strokeBorder(FleetingNotesTheme.borderGradient, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }

    private var backgroundFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.secondarySystemBackground).opacity(0.96))
        }

        return AnyShapeStyle(FleetingNotesTheme.sectionGradient)
    }

    private var sectionFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color(.tertiarySystemBackground))
        }

        return AnyShapeStyle(FleetingNotesTheme.heroGradient)
    }

    private func sectionForeground(isSelected: Bool) -> Color {
        if isSelected {
            return FleetingNotesTheme.textPrimary
        }

        return FleetingNotesTheme.textSecondary
    }
}
