//
//  MoodMeterView.swift
//  Neural Loop
//
//  Created by Codex on 23/05/2026.
//

import SwiftUI

struct MoodMeterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var model: UnifiedDataModel

    @State private var selectedMood: MoodMeterMood?
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    private let columns = Array(repeating: GridItem(.fixed(94), spacing: 8), count: 10)

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        moodGrid
                        selectedMoodSection
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Mood Meter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await saveSelectedMood()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Confirm")
                        }
                    }
                    .disabled(selectedMood == nil || isSaving)
                }
            }
        }
        .alert(
            "Mood could not be saved",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        saveErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Please try again.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How am I feeling?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Choose the word that best matches this moment.")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var moodGrid: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(MoodMeterMood.all) { mood in
                    moodButton(mood)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.materialFallback(reduceTransparency))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
            }
        }
    }

    private var selectedMoodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected mood")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Circle()
                    .fill(selectedMood.map { fillColor(for: $0.quadrant) } ?? AppTheme.textSecondary.opacity(0.30))
                    .frame(width: 14, height: 14)

                Text(selectedMood?.label ?? "Select a mood")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selectedMood.map { fillColor(for: $0.quadrant).opacity(0.18) } ?? Color(.secondarySystemBackground).opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selectedMood.map { fillColor(for: $0.quadrant).opacity(0.66) } ?? Color.black.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func moodButton(_ mood: MoodMeterMood) -> some View {
        let isSelected = selectedMood == mood

        return Button {
            selectedMood = mood
        } label: {
            Text(mood.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
                .foregroundStyle(textColor(for: mood.quadrant))
                .frame(width: 94, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fillColor(for: mood.quadrant).opacity(isSelected ? 1 : 0.78))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Color.white : Color.black.opacity(0.22), lineWidth: isSelected ? 3 : 0.8)
                }
                .shadow(color: isSelected ? fillColor(for: mood.quadrant).opacity(0.34) : .clear, radius: 10, y: 5)
                .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityHint(isSelected ? "Selected mood" : "Selects \(mood.label)")
    }

    private func saveSelectedMood() async {
        guard let selectedMood else { return }

        isSaving = true
        defer { isSaving = false }

        if await model.saveMoodMeterRecord(mood: selectedMood.label) != nil {
            dismiss()
        } else {
            saveErrorMessage = "The selected mood was not saved. Check your connection and try again."
        }
    }

    private func fillColor(for quadrant: MoodMeterQuadrant) -> Color {
        switch quadrant {
        case .red:
            return Color(red: 0.93, green: 0.12, blue: 0.10)
        case .yellow:
            return Color(red: 0.96, green: 0.83, blue: 0.08)
        case .blue:
            return Color(red: 0.16, green: 0.43, blue: 0.78)
        case .green:
            return Color(red: 0.24, green: 0.72, blue: 0.24)
        }
    }

    private func textColor(for quadrant: MoodMeterQuadrant) -> Color {
        switch quadrant {
        case .yellow, .green:
            return Color(red: 0.08, green: 0.12, blue: 0.11)
        case .red, .blue:
            return .white
        }
    }
}

private enum MoodMeterQuadrant {
    case red
    case yellow
    case blue
    case green
}

private struct MoodMeterMood: Identifiable, Hashable {
    let row: Int
    let column: Int
    let label: String

    var id: String { label }

    var quadrant: MoodMeterQuadrant {
        switch (row < 5, column < 5) {
        case (true, true):
            return .red
        case (true, false):
            return .yellow
        case (false, true):
            return .blue
        case (false, false):
            return .green
        }
    }

    static let rows: [[String]] = [
        ["Livid", "Panicked", "Frustrated", "Shocked", "Stunned", "Energised", "Thrilled", "Ecstatic", "Euphoric", "Exhilarated"],
        ["Enraged", "Terrified", "Peeved", "Worried", "Annoyed", "Positive", "Connected", "Joyful", "Enthusiastic", "Elated"],
        ["Irate", "Frightened", "Angry", "Nervous", "Concerned", "Glad", "Inspired", "Happy", "Motivated", "Excited"],
        ["Furious", "Anxious", "Agitated", "Unsure", "Excluded", "Amused", "Focused", "Cheerful", "Proud", "Surprised"],
        ["Disgusted", "Scared", "Troubled", "Restless", "Uneasy", "Satisfied", "Pleased", "Hopeful", "Optimistic", "Lively"],
        ["Apprehensive", "Ashamed", "Guilty", "Deflated", "Complacent", "Easy-going", "Safe", "Chilled", "Respected", "Blessed"],
        ["Sullen", "Glum", "Disheartened", "Discouraged", "Bored", "Relaxed", "Secure", "Content", "Thankful", "Fulfilled"],
        ["Exhausted", "Fatigued", "Sad", "Miserable", "Pessimistic", "Thoughtful", "Composed", "Calm", "Grateful", "Tranquil"],
        ["Alienated", "Depressed", "Disappointed", "Tired", "Confused", "Mellow", "Peaceful", "Balanced", "At Ease", "Collected"],
        ["Despair", "Inconsolable", "Anguished", "Hopeless", "Lonely", "Listless", "Sleepy", "Restful", "Comfy", "Serene"]
    ]

    static let all: [MoodMeterMood] = rows.enumerated().flatMap { rowIndex, labels in
        labels.enumerated().map { columnIndex, label in
            MoodMeterMood(row: rowIndex, column: columnIndex, label: label)
        }
    }
}

#Preview {
    MoodMeterView()
        .environmentObject(UnifiedDataModel(autoStart: false))
}
