import SwiftUI

struct WorkoutSessionDetailView: View {
    @StateObject var viewModel: WorkoutSessionDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                Group {
                    switch viewModel.state {
                    case .loading:
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading Workout Details...")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                    case .loaded(let detail):
                        content(detail)

                    case .error(let message):
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.errorTint)
                            Text(message)
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task {
                                    await viewModel.load()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accentColor)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Workout" : "Workout Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.isEditing {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            viewModel.cancelEditing()
                        }
                        .foregroundColor(AppTheme.errorTint)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            Task {
                                await viewModel.saveChanges()
                            }
                        }
                        .foregroundColor(AppTheme.accentColor)
                        .bold()
                    }
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Edit") {
                            viewModel.startEditing()
                        }
                        .foregroundColor(AppTheme.accentColor)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private func content(_ detail: WorkoutSessionDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                if viewModel.isEditing {
                    editableHeaderSection()
                    editableNotesSection()
                    ForEach($viewModel.draftExercises) { $exercise in
                        editableExerciseSection(exercise: $exercise)
                    }
                } else {
                    headerSection(detail.session)

                    if let notes = detail.session.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    ForEach(detail.exercises, id: \.exerciseId) { exercise in
                        exerciseSection(exercise)
                    }
                }
            }
            .padding(AppTheme.Metrics.screenPadding)
        }
    }

    private func headerSection(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.session_type)
                .font(.title2.bold())
                .foregroundColor(AppTheme.textPrimary)

            HStack {
                Image(systemName: "calendar")
                Text(session.date.formatted(date: .long, time: .omitted))
                
                if let startTime = session.start_time {
                    Text("•")
                    Image(systemName: "clock")
                    Text(startTime)
                }
                
                if let endTime = session.end_time {
                    Text("-")
                    Text(endTime)
                }
            }
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                .fill(AppTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                )
        )
    }

    private func editableHeaderSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Session Title", text: Binding(
                get: { viewModel.draftSession?.session_type ?? "" },
                set: { viewModel.draftSession?.session_type = $0 }
            ))
            .font(.headline)
            .textFieldStyle(.roundedBorder)

            DatePicker("Date", selection: Binding(
                get: { viewModel.draftSession?.date ?? Date() },
                set: { viewModel.draftSession?.date = $0 }
            ), displayedComponents: .date)
            .font(.subheadline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Time")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("09:00", text: Binding(
                        get: { viewModel.draftSession?.start_time ?? "" },
                        set: { viewModel.draftSession?.start_time = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Time")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("10:00", text: Binding(
                        get: { viewModel.draftSession?.end_time ?? "" },
                        set: { viewModel.draftSession?.end_time = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                .fill(AppTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                )
        )
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(notes)
                .font(.body)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                .fill(AppTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                )
        )
    }

    private func editableNotesSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            
            TextField("Notes", text: Binding(
                get: { viewModel.draftSession?.notes ?? "" },
                set: { viewModel.draftSession?.notes = $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3...10)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                .fill(AppTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                )
        )
    }

    private func exerciseSection(_ exercise: WorkoutSessionExerciseDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.exerciseName)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            if exercise.exerciseType.isRepBased {
                ForEach(exercise.sets) { set in
                    HStack {
                        Text(set.set_type == .warmup ? "Warm-up \(set.set_number)" : "Set \(set.set_number)")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        if let weight = set.weight {
                            Text("\(NumericFormatter.format(weight)) kg")
                                .font(.body.monospacedDigit())
                        }
                        Text("×")
                            .foregroundColor(AppTheme.textSecondary)
                        Text("\(set.reps) reps")
                            .font(.body.monospacedDigit())
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                ForEach(Array(exercise.cardioLogs.enumerated()), id: \.offset) { index, log in
                    VStack(alignment: .leading, spacing: 4) {
                        if exercise.cardioLogs.count > 1 {
                            Text("Set \(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if let distance = log.distance_meters {
                                labelValueRow(label: "Distance", value: "\(NumericFormatter.format(distance)) m")
                            }
                            if let duration = log.duration_minutes {
                                labelValueRow(label: "Duration", value: "\(NumericFormatter.format(duration)) min")
                            }
                            if let calories = log.calories {
                                labelValueRow(label: "Calories", value: "\(NumericFormatter.format(calories)) kcal")
                            }
                        }
                        .padding(.leading, exercise.cardioLogs.count > 1 ? 8 : 0)
                    }
                    .padding(.horizontal, 8)

                    if index < exercise.cardioLogs.count - 1 {
                        Divider()
                            .opacity(0.3)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                .fill(AppTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                )
        )
    }

    private func editableExerciseSection(exercise: Binding<WorkoutSessionExerciseDraft>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.wrappedValue.exerciseName)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            ForEach(Array(exercise.sets.wrappedValue.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.removeSet(at: index, from: exercise.wrappedValue.exerciseId)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(AppTheme.errorTint)
                    }

                    Text(set.setType == .warmup ? "W\(set.setNumber)" : "\(set.setNumber)")
                        .font(.subheadline.bold())
                        .frame(width: 24)

                    if exercise.wrappedValue.exerciseType.isRepBased {
                        numericField(
                            text: exercise.sets[index].weightText,
                            placeholder: "kg",
                            keyboardType: .decimalPad
                        )
                        
                        Text("×")
                            .foregroundColor(AppTheme.textSecondary)
                        
                        numericField(
                            text: exercise.sets[index].repsText,
                            placeholder: "reps",
                            keyboardType: .numberPad
                        )
                    } else {
                        numericField(
                            text: exercise.sets[index].durationText,
                            placeholder: "min",
                            keyboardType: .decimalPad
                        )
                        
                        numericField(
                            text: exercise.sets[index].distanceText,
                            placeholder: "m",
                            keyboardType: .decimalPad
                        )
                        
                        numericField(
                            text: exercise.sets[index].caloriesText,
                            placeholder: "kcal",
                            keyboardType: .decimalPad
                        )
                    }
                }
            }

            Button(action: {
                viewModel.addSet(to: exercise.wrappedValue.exerciseId)
            }) {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.accentColor)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                .fill(AppTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                )
        )
    }

    private func labelValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    private func numericField(text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboardType)
            .textFieldStyle(.plain)
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .font(.body.monospacedDigit())
            .multilineTextAlignment(.center)
    }
}
