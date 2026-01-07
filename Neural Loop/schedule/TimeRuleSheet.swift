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
            VStack(spacing: 16) {

                // TIME SECTION
                VStack(spacing: 0) {
                    HStack {
                        Text("Time")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !isAnytime {
                            Text(dateTimeFormatter.string(from: selectedDateTime))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding()

                    Divider()

                    if !isAnytime {
                        DatePicker(
                            "Select Date & Time",
                            selection: $selectedDateTime,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding(.horizontal)
                    }

                    Toggle("Anytime", isOn: $isAnytime)
                        .padding()
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // DURATION SECTION
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Duration", isOn: $isDurationEnabled)

                    if isDurationEnabled {
                        // QUICK PRESETS
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(quickMinutes, id: \.self) { min in
                                    quickButton(title: "\(min)") {
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
                        .frame(height: 150)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer()
            }
            .padding()
            .navigationTitle("Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
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
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func quickButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var dateTimeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }
}
