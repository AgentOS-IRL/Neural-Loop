import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingFinishConfirmation = false
    @State private var isLibraryPresented = false
    @State private var previewGallery: ExerciseMediaGallery?
    @State private var expandedExerciseID: Int64?
    @State private var highlightedExerciseID: Int64?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.draft.exercises.enumerated()), id: \.element.id) { index, state in
                                    let isLastInGroup = index == viewModel.draft.exercises.count - 1 ||
                                                       viewModel.draft.exercises[index + 1].supersetGroupID != state.supersetGroupID ||
                                                       state.supersetGroupID == nil

                                    exerciseCard(for: state, proxy: proxy)
                                        .id(state.id)
                                        .padding(.horizontal)
                                        .padding(.bottom, isLastInGroup ? 16 : 8)
                                }

                                recommendationContent(proxy: proxy)
                                    .padding(.horizontal)
                                    .padding(.bottom, 16)

                                addExerciseButton
                                    .padding(.horizontal)
                                    .padding(.bottom, 20)
                            }
                            .padding(.vertical)
                        }
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
                        Task {
                            await viewModel.addExercises(from: selections)
                        }
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
            await viewModel.loadRecommendationsIfNeeded()
        }
    }

    @ViewBuilder
    private func exerciseCard(for state: WorkoutExerciseCardState, proxy: ScrollViewProxy) -> some View {
        if expandedExerciseID == state.id {
            ExpandedWorkoutExerciseCard(
                card: state,
                dataManager: viewModel.db,
                onCopySet: { setID in
                    viewModel.copySet(exerciseID: state.id, sourceSetID: setID)
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
                onUseSuggestion: { setID in
                    viewModel.useSuggestion(exerciseID: state.id, setID: setID)
                },
                onUseAllSuggestions: {
                    viewModel.useAllSuggestions(exerciseID: state.id)
                },
                onCollapse: {
                    withAnimation(cardAnimation) {
                        expandedExerciseID = nil
                    }
                },
                onPreviewRequested: { gallery in
                    previewGallery = gallery
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
        } else {
            CompactWorkoutExerciseCard(
                card: state,
                isHighlighted: highlightedExerciseID == state.id,
                onExpand: {
                    expandExercise(state.id, proxy: proxy)
                }
            )
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func recommendationContent(proxy: ScrollViewProxy) -> some View {
        if viewModel.isLoadingRecommendations {
            WorkoutRecommendationLoadingCard()
        } else if let sourceDate = viewModel.recommendationSourceDate,
                  !viewModel.recommendations.isEmpty {
            WorkoutRecommendationSection(
                routineName: viewModel.draft.session.session_type,
                sourceDate: sourceDate,
                recommendations: viewModel.recommendations,
                onAdd: { recommendationID in
                    guard let exerciseID = viewModel.addRecommendation(id: recommendationID) else { return }
                    expandExercise(exerciseID, proxy: proxy)
                },
                onAddAll: {
                    let addedExerciseIDs = viewModel.addAllRecommendations()
                    guard let firstID = addedExerciseIDs.first else { return }
                    withAnimation(cardAnimation) {
                        expandedExerciseID = nil
                        highlightedExerciseID = firstID
                    }
                    scrollToExercise(firstID, proxy: proxy)
                    clearHighlight(after: 1.2, exerciseID: firstID)
                }
            )
        }
    }

    private var cardAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.24)
    }

    private func expandExercise(_ exerciseID: Int64, proxy: ScrollViewProxy) {
        withAnimation(cardAnimation) {
            expandedExerciseID = exerciseID
            highlightedExerciseID = nil
        }
        scrollToExercise(exerciseID, proxy: proxy)
    }

    private func scrollToExercise(_ exerciseID: Int64, proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            withAnimation(cardAnimation) {
                proxy.scrollTo(exerciseID, anchor: .top)
            }
        }
    }

    private func clearHighlight(after seconds: Double, exerciseID: Int64) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard highlightedExerciseID == exerciseID else { return }
            withAnimation(cardAnimation) {
                highlightedExerciseID = nil
            }
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
