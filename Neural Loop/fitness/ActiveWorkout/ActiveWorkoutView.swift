import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0A0A").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(viewModel.exerciseStates) { state in
                                WorkoutExerciseCard(
                                    card: state,
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
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }

                    if viewModel.isTimerRunning {
                        timerOverlay
                    }
                    
                    finishButton
                }
            }
            .navigationTitle(viewModel.session.session_type)
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
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Active Session")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(viewModel.session.session_type)
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
            
            Text(timeString(from: viewModel.restTimerSeconds))
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
            
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
    
    private var finishButton: some View {
        Button(action: {
            Task {
                await viewModel.finishWorkout()
                if viewModel.errorMessage == nil {
                    dismiss()
                }
            }
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
