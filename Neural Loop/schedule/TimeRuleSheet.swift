import Foundation
import SwiftUI
import EventKit

struct TimeRuleSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onSave: (TaskTiming) -> Void
    let initialTiming: TaskTiming?

    @State private var selectedDateTime: Date
    @State private var isAnytime: Bool
    @State private var isDurationEnabled: Bool

    @State private var selectedHours: Int
    @State private var selectedMinutes: Int

    private let quickMinutes = [15, 30, 45]
    private let quickHours = [1, 2]

    init(initialTiming: TaskTiming? = nil, onSave: @escaping (TaskTiming) -> Void) {
        self.initialTiming = initialTiming
        self.onSave = onSave

        if let t = initialTiming {
            if t.start == .distantFuture {
                _isAnytime = State(initialValue: true)
                _selectedDateTime = State(initialValue: Date())
            } else {
                _isAnytime = State(initialValue: false)
                _selectedDateTime = State(initialValue: t.start)
            }

            if t.duration <= 0 {
                _isDurationEnabled = State(initialValue: false)
                _selectedHours = State(initialValue: 0)
                _selectedMinutes = State(initialValue: 15)
            } else {
                let totalMins = Int(t.duration / 60)
                _isDurationEnabled = State(initialValue: true)
                _selectedHours = State(initialValue: totalMins / 60)
                _selectedMinutes = State(initialValue: totalMins % 60)
            }
        } else {
            _selectedDateTime = State(initialValue: Date())
            _isAnytime = State(initialValue: false)
            _isDurationEnabled = State(initialValue: true)
            _selectedHours = State(initialValue: 0)
            _selectedMinutes = State(initialValue: 15)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FleetingNotesTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FleetingNotesTheme.Metrics.sectionSpacing) {

                        // TIME SECTION
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Time")
                            ThemedCard {
                                HStack {
                                    Text("Start")
                                        .foregroundColor(FleetingNotesTheme.textPrimary)
                                    Spacer()
                                    if !isAnytime {
                                        Text(dateTimeFormatter.string(from: selectedDateTime))
                                            .font(.body.bold())
                                            .foregroundColor(FleetingNotesTheme.accentColor)
                                    }
                                }
                                .padding(.vertical, 4)

                                if !isAnytime {
                                    Divider()
                                        .background(FleetingNotesTheme.textSecondary.opacity(0.1))
                                    
                                    DatePicker(
                                        "Select Date & Time",
                                        selection: $selectedDateTime,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                }

                                Divider()
                                    .background(FleetingNotesTheme.textSecondary.opacity(0.1))

                                Toggle(isOn: $isAnytime) {
                                    Text("Anytime")
                                        .foregroundColor(FleetingNotesTheme.textPrimary)
                                }
                                .tint(FleetingNotesTheme.accentColor)
                            }
                        }

                        // DURATION SECTION
                        VStack(alignment: .leading, spacing: 4) {
                            themedSectionHeader("Duration")
                            ThemedCard {
                                Toggle(isOn: $isDurationEnabled) {
                                    Text("Set Duration")
                                        .foregroundColor(FleetingNotesTheme.textPrimary)
                                }
                                .tint(FleetingNotesTheme.accentColor)

                                if isDurationEnabled {
                                    Divider()
                                        .background(FleetingNotesTheme.textSecondary.opacity(0.1))

                                    // QUICK PRESETS
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(quickMinutes, id: \.self) { min in
                                                quickButton(title: "\(min)m") {
                                                    selectedHours = 0
                                                    selectedMinutes = min
                                                }
                                            }

                                            quickButton(title: "1h") {
                                                selectedHours = 1
                                                selectedMinutes = 0
                                            }

                                            quickButton(title: "2h") {
                                                selectedHours = 2
                                                selectedMinutes = 0
                                            }
                                        }
                                    }
                                    .padding(.vertical, 8)

                                    // PICKER
                                    HStack {
                                        Picker("Hours", selection: $selectedHours) {
                                            ForEach(0..<6, id: \.self) { Text("\($0) hr") }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)

                                        Picker("Minutes", selection: $selectedMinutes) {
                                            ForEach(0..<60, id: \.self) { Text("\($0) min") }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)
                                    }
                                    .frame(height: 120)
                                    .background(FleetingNotesTheme.textSecondary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                    }
                    .padding(FleetingNotesTheme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { 
                        Image(systemName: "xmark")
                            .foregroundColor(FleetingNotesTheme.textPrimary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let duration = TimeInterval((selectedHours * 3600) + (selectedMinutes * 60))
                        onSave(
                            TaskTiming(
                                start: isAnytime ? .distantFuture : selectedDateTime,
                                duration: isDurationEnabled ? duration : 0
                            )
                        )
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                    .foregroundColor(FleetingNotesTheme.accentColor)
                }
            }
        }
    }

    private func quickButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(FleetingNotesTheme.sectionGradient)
                .foregroundColor(FleetingNotesTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FleetingNotesTheme.borderGradient, lineWidth: 1)
                )
        }
    }

    private var dateTimeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }
}
