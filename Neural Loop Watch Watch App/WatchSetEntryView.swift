import SwiftUI

struct WatchSetEntryView: View {
    let exerciseID: String
    let setID: String
    @EnvironmentObject var store: WatchWorkoutStore
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel: WatchSetEntryViewModel
    @FocusState private var focusedField: FocusedField?
    @State private var showSavedFeedback = false
    
    enum FocusedField: Hashable {
        case kg
        case reps
    }
    
    init(exerciseID: String, setID: String) {
        self.exerciseID = exerciseID
        self.setID = setID
        // We initialize with a placeholder, then re-initialize in onAppear with store
        _viewModel = StateObject(wrappedValue: WatchSetEntryViewModel(
            exerciseID: exerciseID,
            setID: setID,
            store: WatchWorkoutStore.shared,
            set: nil
        ))
    }
    
    private var exerciseSet: SetSnapshot? {
        store.currentSnapshot?.exercises
            .first(where: { $0.id == exerciseID })?
            .sets.first(where: { $0.id == setID })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // MARK: - Weight Section
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.caption2)
                        Text("kg")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Button {
                            viewModel.adjustKg(by: -0.5)
                            focusedField = .kg
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "minus")
                                    .font(.body.bold())
                                Text("0.5")
                                    .font(.system(size: 8))
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                        
                        Text(String(format: "%.1f", viewModel.kg))
                            .font(.title2)
                            .bold()
                            .frame(minWidth: 55)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(focusedField == .kg ? Color.accentColor : Color.clear, lineWidth: 2)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            )
                            .onTapGesture {
                                focusedField = .kg
                            }
                        
                        Button {
                            viewModel.adjustKg(by: 0.5)
                            focusedField = .kg
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "plus")
                                    .font(.body.bold())
                                Text("0.5")
                                    .font(.system(size: 8))
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                
                // MARK: - Reps Section
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.caption2)
                        Text("reps")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Button {
                            viewModel.adjustReps(by: -1)
                            focusedField = .reps
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "minus")
                                    .font(.body.bold())
                                Text("1")
                                    .font(.system(size: 8))
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                        
                        Text("\(viewModel.reps)")
                            .font(.title2)
                            .bold()
                            .frame(minWidth: 55)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(focusedField == .reps ? Color.accentColor : Color.clear, lineWidth: 2)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            )
                            .onTapGesture {
                                focusedField = .reps
                            }
                        
                        Button {
                            viewModel.adjustReps(by: 1)
                            focusedField = .reps
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "plus")
                                    .font(.body.bold())
                                Text("1")
                                    .font(.system(size: 8))
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }

                // MARK: - Save Feedback
                if showSavedFeedback {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Saved")
                    }
                    .font(.caption2)
                    .foregroundColor(.green)
                    .transition(.opacity.combined(with: .scale))
                }

                // MARK: - Action Buttons
                VStack(spacing: 8) {
                    // Save button — saves values without completing
                    Button {
                        viewModel.commitValues()
                        withAnimation {
                            showSavedFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showSavedFeedback = false
                            }
                        }
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    // Complete Set button — saves + marks complete + triggers rest timer
                    if !viewModel.isCompleted {
                        Button {
                            viewModel.commitAndComplete()
                            
                            // Check if rest timer should be shown (Plan 527)
                            if let exercise = store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID }),
                               let restSeconds = exercise.restDurationSeconds,
                               restSeconds > 0 {
                                store.lastCompletedSetInfo = CompletedSetInfo(
                                    exerciseID: exerciseID,
                                    setID: setID,
                                    restDurationSeconds: restSeconds
                                )
                            }
                            
                            dismiss()
                        } label: {
                            Label("Complete Set", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        // Undo completion
                        Button {
                            viewModel.undoComplete()
                        } label: {
                            Label("Mark Incomplete", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    
                    // Done — just dismiss
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Set \(exerciseSet?.setNumber ?? 0)")
        .digitalCrownRotation(
            crownBinding,
            from: 0,
            through: focusedField == .kg ? 500 : 100,
            by: focusedField == .kg ? 0.5 : 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear {
            // Re-initialize with actual store and set data
            viewModel.reinitialize(with: store, set: exerciseSet)
            if focusedField == nil {
                focusedField = .kg
            }
        }
    }
    
    private var crownBinding: Binding<Double> {
        Binding(
            get: {
                focusedField == .kg ? viewModel.kg : Double(viewModel.reps)
            },
            set: { newValue in
                if focusedField == .kg {
                    viewModel.setKg(newValue)
                } else {
                    viewModel.setReps(Int(newValue))
                }
            }
        )
    }
}
