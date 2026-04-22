import SwiftUI

struct NewWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NewWorkoutViewModel()
    @State private var isLibraryPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    workoutOptionsMenu
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .sheet(isPresented: $isLibraryPresented) {
                ExerciseLibrarySelectionSheet(
                    items: viewModel.availableExercises,
                    initiallySelectedExerciseIDs: viewModel.selectedExerciseIDs,
                    onAdd: { selections in
                        viewModel.syncExercises(with: selections)
                    }
                )
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading exercises")
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
        } else if viewModel.exerciseCards.isEmpty {
            emptyWorkoutState
        } else {
            populatedWorkoutState
        }
    }

    private var emptyWorkoutState: some View {
        VStack(spacing: 18) {
            if let errorMessage = viewModel.errorMessage {
                errorBanner(errorMessage)
            }

            Spacer()

            Button {
                isLibraryPresented = true
            } label: {
                Label("Add Exercises", systemImage: "plus")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 190, minHeight: 54)
                    .background {
                        Capsule()
                            .fill(AppTheme.accentGradient)
                    }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
    }

    private var populatedWorkoutState: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.cardSpacing) {
                Text(viewModel.subtitleText)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 16)

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }

                ForEach(viewModel.exerciseCards) { card in
                    WorkoutExerciseCard(
                        card: card,
                        onAddSet: {
                            viewModel.addSet(to: card.id)
                        },
                        onWeightChange: { setID, value in
                            viewModel.updateWeight(cardID: card.id, setID: setID, value: value)
                        },
                        onRepsChange: { setID, value in
                            viewModel.updateReps(cardID: card.id, setID: setID, value: value)
                        }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Metrics.screenPadding)
            .padding(.bottom, 104)
        }
    }

    private var workoutOptionsMenu: some View {
        Menu {
            Button("Reorder Exercise", action: {})
            Button("Capture Photo", action: {})
            Button("Import Photo", action: {})
            Button("Describe Routine", action: {})
            Button("Settings", action: {})
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel("Workout options")
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
                isLibraryPresented = true
            } label: {
                Label("Add Exercises", systemImage: "plus")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textPrimary)
            .background {
                Capsule()
                    .fill(AppTheme.cardGradient)
            }
            .overlay {
                Capsule()
                    .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
            }

            Button {
                Task {
                    let didSave = await viewModel.save()
                    if didSave {
                        dismiss()
                    }
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    Text("Save")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background {
                Capsule()
                    .fill(viewModel.canSave ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(Color.gray.opacity(0.45)))
            }
            .disabled(!viewModel.canSave)
        }
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.errorTint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.errorTint.opacity(0.10))
            }
    }
}

#Preview {
    NewWorkoutView()
}
