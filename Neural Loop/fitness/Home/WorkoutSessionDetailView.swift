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
            .navigationTitle("Workout Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
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
                headerSection(detail.session)

                if let notes = detail.session.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                ForEach(detail.exercises, id: \.exerciseId) { exercise in
                    exerciseSection(exercise)
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

    private func exerciseSection(_ exercise: WorkoutSessionExerciseDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.exerciseName)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            if exercise.exerciseType.isRepBased {
                ForEach(exercise.sets) { set in
                    HStack {
                        Text("Set \(set.set_number)")
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
            } else if let log = exercise.cardioLog {
                VStack(alignment: .leading, spacing: 8) {
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
                .padding(.horizontal, 8)
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
}
