import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingFinishConfirmation = false
    @State private var isLibraryPresented = false
    @State private var previewGallery: ExerciseMediaGallery?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.draft.exercises.enumerated()), id: \.element.id) { index, state in
                                let isLastInGroup = index == viewModel.draft.exercises.count - 1 ||
                                                   viewModel.draft.exercises[index + 1].supersetGroupID != state.supersetGroupID ||
                                                   state.supersetGroupID == nil

                                WorkoutExerciseCard(
                                    card: state,
                                    dataManager: viewModel.db,
                                    onAddSet: {
                                        viewModel.addSet(to: state.id)
                                    },
                                    onWeightChange: { setID, weight in
                                        viewModel.updateWeight(for: state.id, setID: setID, weightText: weight)
                                    },
                                    onRepsChange: { setID, reps in
                                        viewModel.updateReps(for: state.id, setID: setID, repsText: reps)
                                    },
                                    onDurationChange: { setID, duration in
                                        viewModel.updateDuration(for: state.id, setID: setID, durationText: duration)
                                    },
                                    onDistanceChange: { setID, distance in
                                        viewModel.updateDistance(for: state.id, setID: setID, distanceText: distance)
                                    },
                                    onCaloriesChange: { setID, calories in
                                        viewModel.updateCalories(for: state.id, setID: setID, caloriesText: calories)
                                    },
                                    onToggleComplete: { setID in
                                        viewModel.toggleSetCompletion(exerciseID: state.id, setID: setID)
                                    },
                                    onPreviewRequested: { gallery in
                                        previewGallery = gallery
                                    }
                                )
                                .padding(.horizontal)
                                .padding(.bottom, isLastInGroup ? 20 : 8)
                            }

                            addExerciseButton
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                        .padding(.vertical)
                    }

                    if viewModel.isTimerRunning {
                        timerOverlay
                    }
                    
                    finishButton
                }
            }
            .navigationTitle(viewModel.draft.session.session_type)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("Finish workout?", isPresented: $isShowingFinishConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Finish Workout", role: .destructive) {
                    Task {
                        await viewModel.finishWorkout()
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("This will save the workout session and close the active workout.")
            }
            .sheet(item: $previewGallery) { gallery in
                ExerciseMediaPreviewSheet(gallery: gallery, allowsMotion: !reduceMotion)
            }
            .sheet(isPresented: $isLibraryPresented) {
                ExerciseLibrarySelectionSheet(
                    items: viewModel.availableExercises,
                    initiallySelectedExerciseIDs: viewModel.currentExerciseIDs,
                    onAdd: { selections in
                        viewModel.addExercises(from: selections)
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .task {
            await viewModel.loadExerciseCatalog()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Active Session")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(viewModel.draft.session.session_type)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
    }

    private var timerOverlay: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundColor(.blue)
            
            Text("Rest Timer:")
                .font(.subheadline)
                .foregroundColor(.gray)

            if let endDate = viewModel.restEndsAt, endDate > Date() {
                Text(timerInterval: Date.now...endDate, countsDown: true)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .monospacedDigit()
            } else {
                Text(timeString(from: viewModel.restTimerSeconds))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.stopTimer()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private var addExerciseButton: some View {
        Button {
            isLibraryPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Add Exercise")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(AppTheme.accentColor)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.cardGradient)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.accentColor.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingCatalog)
    }
    
    private var finishButton: some View {
        Button(action: {
            isShowingFinishConfirmation = true
        }) {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text("Finish Workout")
                        .font(.headline)
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
        .disabled(viewModel.isLoading)
        .padding()
    }
}
