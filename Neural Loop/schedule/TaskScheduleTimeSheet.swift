import Foundation
import SwiftUI
import EventKit

struct TaskScheduleTimeSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onSave: (TaskTiming) -> Void

    @State private var selectedTime: Date = Date()
    @State private var isAnytime: Bool = false
    @State private var isDurationEnabled: Bool = true

    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 15

    private let quickMinutes = [15, 30, 45]
    private let quickHours = [1, 2]

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
                            Text(timeFormatter.string(from: selectedTime))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding()

                    Divider()

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
                                ForEach(0..<6, id: \.self) {
                                    Text("\($0) hr")
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Minutes", selection: $selectedMinutes) {
                                ForEach(0..<60, id: \.self) {
                                    Text("\($0) min")
                                }
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let duration = TimeInterval((selectedHours * 3600) + (selectedMinutes * 60))
                        onSave(
                            TaskTiming(
                                start: isAnytime ? Date.distantFuture : selectedTime,
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

    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }
}
