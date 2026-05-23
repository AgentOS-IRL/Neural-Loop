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

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    let gridSize = gridSize(for: proxy.size)

                    VStack(alignment: .leading, spacing: 18) {
                        header

                        Spacer(minLength: 0)

                        moodGrid(size: gridSize)
                            .frame(width: gridSize, height: gridSize)
                            .frame(maxWidth: .infinity)

                        Spacer(minLength: 0)

                        selectedMoodSection
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func moodGrid(size: CGFloat) -> some View {
        let inset = size * 0.07
        let step = (size - (inset * 2)) / CGFloat(MoodMeterMood.columnCount - 1)

        return ZStack {
            moodQuadrantBackground

            ForEach(MoodMeterMood.all) { mood in
                let center = CGPoint(
                    x: inset + CGFloat(mood.column) * step,
                    y: inset + CGFloat(mood.row) * step
                )
                let dotSize = dotSize(for: mood, baseSize: max(10, step * 0.36))

                Circle()
                    .fill(fillColor(for: mood.quadrant))
                    .frame(width: dotSize, height: dotSize)
                    .position(center)
                    .shadow(
                        color: selectedMood == mood ? fillColor(for: mood.quadrant).opacity(0.42) : .clear,
                        radius: selectedMood == mood ? 14 : 0,
                        y: selectedMood == mood ? 6 : 0
                    )
                    .animation(.spring(response: 0.28, dampingFraction: 0.76), value: selectedMood)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    updateSelectedMood(from: value.location, gridSize: size, inset: inset, step: step)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mood meter grid")
        .accessibilityValue(selectedMood?.label ?? "No mood selected")
        .accessibilityHint("Drag across the grid to select a mood")
    }

    private var selectedMoodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(selectedMood.map { fillColor(for: $0.quadrant) } ?? AppTheme.textSecondary.opacity(0.30))
                    .frame(width: 12, height: 12)

                Text("Selected mood")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
            }

            Text(selectedMood?.label ?? "Move your finger across the grid")
                .font(.system(size: selectedMood == nil ? 20 : 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity, alignment: .leading)

            moodCoordinateText
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(selectedMood.map { fillColor(for: $0.quadrant).opacity(0.18) } ?? Color(.secondarySystemBackground).opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selectedMood.map { fillColor(for: $0.quadrant).opacity(0.66) } ?? Color.black.opacity(0.08), lineWidth: 1)
        }
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

    private var moodCoordinateText: Text {
        guard let selectedMood else {
            return Text("Touch a dot to choose the closest mood")
        }

        let pleasantness = selectedMood.column < 5 ? "less pleasant" : "more pleasant"
        let energy = selectedMood.row < 5 ? "higher energy" : "lower energy"
        return Text("\(energy.capitalized) - \(pleasantness.capitalized)")
    }

    private var moodQuadrantBackground: some View {
        GeometryReader { proxy in
            let halfWidth = proxy.size.width / 2
            let halfHeight = proxy.size.height / 2

            ZStack {
                quadrantBlock(.red)
                    .frame(width: halfWidth, height: halfHeight)
                    .position(x: halfWidth / 2, y: halfHeight / 2)

                quadrantBlock(.yellow)
                    .frame(width: halfWidth, height: halfHeight)
                    .position(x: halfWidth + halfWidth / 2, y: halfHeight / 2)

                quadrantBlock(.blue)
                    .frame(width: halfWidth, height: halfHeight)
                    .position(x: halfWidth / 2, y: halfHeight + halfHeight / 2)

                quadrantBlock(.green)
                    .frame(width: halfWidth, height: halfHeight)
                    .position(x: halfWidth + halfWidth / 2, y: halfHeight + halfHeight / 2)
            }
        }
        .background(AppTheme.materialFallback(reduceTransparency))
    }

    private func quadrantBlock(_ quadrant: MoodMeterQuadrant) -> some View {
        fillColor(for: quadrant)
            .opacity(reduceTransparency ? 0.20 : 0.13)
    }

    private func updateSelectedMood(from location: CGPoint, gridSize: CGFloat, inset: CGFloat, step: CGFloat) {
        let boundedX = min(max(location.x, inset), gridSize - inset)
        let boundedY = min(max(location.y, inset), gridSize - inset)
        let column = Int(((boundedX - inset) / step).rounded()).clamped(to: 0...(MoodMeterMood.columnCount - 1))
        let row = Int(((boundedY - inset) / step).rounded()).clamped(to: 0...(MoodMeterMood.rowCount - 1))
        let mood = MoodMeterMood.rows[row][column]

        if selectedMood?.row != row || selectedMood?.column != column {
            selectedMood = MoodMeterMood(row: row, column: column, label: mood)
        }
    }

    private func dotSize(for mood: MoodMeterMood, baseSize: CGFloat) -> CGFloat {
        guard let selectedMood else {
            return baseSize
        }

        let rowDistance = CGFloat(mood.row - selectedMood.row)
        let columnDistance = CGFloat(mood.column - selectedMood.column)
        let distance = sqrt(rowDistance * rowDistance + columnDistance * columnDistance)
        let influence = max(0, 1 - (distance / 4))
        return baseSize + (baseSize * 1.25 * influence)
    }

    private func gridSize(for size: CGSize) -> CGFloat {
        let horizontalSpace = size.width - (AppTheme.Metrics.screenPadding * 2)
        let reservedVerticalSpace: CGFloat = 218
        let verticalSpace = size.height - reservedVerticalSpace
        return max(240, min(horizontalSpace, verticalSpace))
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
}

private enum MoodMeterQuadrant {
    case red
    case yellow
    case blue
    case green
}

private struct MoodMeterMood: Identifiable, Hashable {
    static let rowCount = 10
    static let columnCount = 10

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
