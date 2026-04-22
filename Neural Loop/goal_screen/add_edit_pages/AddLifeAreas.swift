//
//  AddLifeAreas.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 08/01/2026.
//

import SwiftUI

struct AddLifeAreas: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var vision: String
    @State private var color: String
    @State private var icon: String
    @State private var showIconPicker: Bool = false
    @EnvironmentObject var model: UnifiedDataModel

    private let existingLifeArea: LifeAreas?
    var onSaved: () -> Void

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

    init(lifeArea: LifeAreas? = nil, onSaved: @escaping () -> Void) {
        self.existingLifeArea = lifeArea
        self.onSaved = onSaved
        _name = State(initialValue: lifeArea?.name ?? "")
        _vision = State(initialValue: lifeArea?.vision ?? "")
        _color = State(initialValue: lifeArea?.color ?? "#4F46E5")
        _icon = State(initialValue: lifeArea?.icon ?? "heart")
    }

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

                Section(header: Text("Settings")) {
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

                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            Text("Icon")

                            Spacer()

                            Image(systemName: icon)
                                .foregroundStyle(.primary)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.2))
                                )
                        }
                    }
                }
            }
            .navigationTitle(existingLifeArea == nil ? "Add Life Area" : "Edit Life Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(existingLifeArea == nil ? "Save" : "Update") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showIconPicker) {
            IconSelectionSheet(
                initialIcon: icon,
            ) { selectedIcon in
                icon = selectedIcon
            }
        }
    }

    // MARK: - Actions

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVision = vision.trimmingCharacters(in: .whitespacesAndNewlines)
        let area = LifeAreas(
            id: existingLifeArea?.id,
            name: trimmedName,
            vision: trimmedVision.isEmpty ? nil : trimmedVision,
            is_sample: existingLifeArea?.is_sample ?? false,
            color: color,
            icon: icon
        )
        if existingLifeArea == nil {
            await model.saveLifeArea(area)
        } else {
            await model.updateLifeArea(area)
        }
        onSaved()
        dismiss()
        
    }
}
