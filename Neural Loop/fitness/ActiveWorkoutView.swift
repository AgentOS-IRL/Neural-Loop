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
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    finishButton
                }
            }
            .navigationTitle(viewModel.session.session_type)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
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
    
    private var finishButton: some View {
        Button(action: {
            viewModel.finishWorkout()
            dismiss()
        }) {
            Text("Finish Workout")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
        }
        .padding()
    }
}
