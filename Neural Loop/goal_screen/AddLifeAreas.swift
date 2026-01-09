//
//  AddLifeAreas.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 08/01/2026.
//

import SwiftUI

struct AddLifeAreas: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var vision: String = ""
    @State private var color: String = "#4F46E5" // default indigo

    private let colorOptions: [(name: String, hex: String)] = [
        ("Indigo", "#4F46E5"),
        ("Blue", "#2563EB"),
        ("Green", "#16A34A"),
        ("Yellow", "#EAB308"),
        ("Orange", "#F97316"),
        ("Red", "#DC2626"),
        ("Pink", "#DB2777"),
        ("Purple", "#7C3AED"),
        ("Gray", "#6B7280")
    ]

    var onSaved: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Life Area")) {
                    TextField("Name", text: $name)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vision (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $vision)
                            .frame(minHeight: 100)
                    }
                }

                Section(header: Text("Color")) {
                    Picker(
                        selection: $color,
                        label: HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 14, height: 14)

                            Text(
                                colorOptions.first(where: { $0.hex == color })?.name ?? "Color"
                            )
                        }
                    ) {
                        ForEach(colorOptions, id: \.hex) { option in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: option.hex))
                                    .frame(width: 14, height: 14)

                                Text(option.name)
                            }
                            .tag(option.hex)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Add Life Area")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func save() async {
        do {
            let manager = DBManager.newInstance()
            let area = LifeAreas(
                id: nil,
                name: name,
                vision: vision.isEmpty ? nil : vision,
                is_sample: false,
                color: color,
                icon: "target"
            )
            try await manager.addLifeArea(area)
            onSaved()
            dismiss()
        } catch {
            print("Failed to save life area:", error)
        }
    }
}
