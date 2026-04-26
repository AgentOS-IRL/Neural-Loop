import Foundation
import Combine
import SwiftUI

@MainActor
final class WatchSetEntryViewModel: ObservableObject {
    @Published var kg: Double = 0
    @Published var reps: Int = 0
    @Published var isCompleted: Bool = false
    
    private var initialKg: Decimal?
    private var initialReps: Int?
    private var initialIsCompleted: Bool = false
    private var kgEdited = false
    private var repsEdited = false
    
    let exerciseID: String
    let setID: String
    var store: WatchWorkoutStore
    
    init(exerciseID: String, setID: String, store: WatchWorkoutStore, set: SetSnapshot?) {
        self.exerciseID = exerciseID
        self.setID = setID
        self.store = store
        
        if let set = set {
            let currentKg = (set.values.kg as NSDecimalNumber?)?.doubleValue ?? 0
            let currentReps = set.values.reps ?? 0
            
            self.kg = currentKg
            self.reps = currentReps
            self.isCompleted = set.isCompleted
            
            self.initialKg = set.values.kg
            self.initialReps = set.values.reps
            self.initialIsCompleted = set.isCompleted
        }
    }
    
    func reinitialize(with store: WatchWorkoutStore, set: SetSnapshot?) {
        self.store = store
        if let set = set {
            let currentKg = (set.values.kg as NSDecimalNumber?)?.doubleValue ?? 0
            let currentReps = set.values.reps ?? 0
            
            self.kg = currentKg
            self.reps = currentReps
            self.isCompleted = set.isCompleted
            
            self.initialKg = set.values.kg
            self.initialReps = set.values.reps
            self.initialIsCompleted = set.isCompleted
            self.kgEdited = false
            self.repsEdited = false
        }
    }

    func setKg(_ value: Double) {
        let clampedKg = clamp(value, in: 0...500)
        if kg != clampedKg {
            kg = clampedKg
            kgEdited = true
        }
    }

    func setReps(_ value: Int) {
        let clampedReps = Int(clamp(Double(value), in: 0...100))
        if reps != clampedReps {
            reps = clampedReps
            repsEdited = true
        }
    }
    
    func adjustKg(by amount: Double) {
        setKg(kg + amount)
    }
    
    func adjustReps(by amount: Int) {
        setReps(reps + amount)
    }
    
    // MARK: - Separated Actions
    
    /// Saves only weight/rep values without changing completion state.
    func commitValues() {
        let kgChanged = kgEdited && Decimal(kg) != initialKg
        let repsChanged = repsEdited && reps != initialReps
        
        if kgChanged || repsChanged {
            store.updateSetValues(
                exerciseID: exerciseID,
                setID: setID,
                kg: kgChanged ? Decimal(kg) : nil,
                reps: repsChanged ? reps : nil
            )
            // Update initial values so subsequent saves detect correctly
            if kgChanged { initialKg = Decimal(kg) }
            if repsChanged { initialReps = reps }
            kgEdited = false
            repsEdited = false
        }
    }
    
    /// Saves values and marks the set as completed.
    func commitAndComplete() {
        commitValues()
        if !isCompleted {
            isCompleted = true
            store.toggleSetCompletion(
                exerciseID: exerciseID,
                setID: setID,
                isCompleted: true
            )
        }
    }
    
    /// Marks the set as incomplete.
    func undoComplete() {
        if isCompleted {
            isCompleted = false
            store.toggleSetCompletion(
                exerciseID: exerciseID,
                setID: setID,
                isCompleted: false
            )
        }
    }

    /// Dispatches any changed values to the store without dismissing.
    /// Legacy method preserved for backward compatibility.
    func commitChanges() {
        commitValues()
        
        let completionChanged = isCompleted != initialIsCompleted
        if completionChanged {
            store.toggleSetCompletion(
                exerciseID: exerciseID,
                setID: setID,
                isCompleted: isCompleted
            )
        }
    }
    
    func handleDone(dismiss: () -> Void) {
        commitChanges()
        dismiss()
    }
    
    private func clamp(_ value: Double, in range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
