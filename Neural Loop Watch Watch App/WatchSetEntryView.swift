import SwiftUI

struct WatchSetEntryView: View {
    let exerciseID: String
    let setID: String
    @EnvironmentObject var store: WatchWorkoutStore
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel: WatchSetEntryViewModel
    @FocusState private var focusedField: FocusedField?
    
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
            VStack(spacing: 16) {
                // Weight Section
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.caption2)
                        Text("kg")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Button {
                            viewModel.adjustKg(by: -0.5)
                            focusedField = .kg
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.plain)
                        .frame(width: 40, height: 40)
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
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                
                // Reps Section
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.caption2)
                        Text("reps")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Button {
                            viewModel.adjustReps(by: -1)
                            focusedField = .reps
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.plain)
                        .frame(width: 40, height: 40)
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
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }

                Toggle("Completed", isOn: $viewModel.isCompleted)
                    .padding(.vertical, 4)
                
                Button("Done") {
                    viewModel.commitChanges()
                    
                    // Check if rest timer should be shown (Plan 527)
                    if viewModel.isCompleted,
                       let exercise = store.currentSnapshot?.exercises.first(where: { $0.id == exerciseID }),
                       let restSeconds = exercise.restDurationSeconds,
                       restSeconds > 0 {
                        store.lastCompletedSetInfo = CompletedSetInfo(
                            exerciseID: exerciseID,
                            setID: setID,
                            restDurationSeconds: restSeconds
                        )
                    }
                    
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
