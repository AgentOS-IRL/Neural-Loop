import Foundation
import SwiftUI

@MainActor
final class WatchSetEntryViewModel: ObservableObject {
    @Published var kg: Double = 0
    @Published var reps: Int = 0
    @Published var isCompleted: Bool = false
    
    @Published var initialKg: Double = 0
    @Published var initialReps: Int = 0
    @Published var initialIsCompleted: Bool = false
    
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
            
            self.initialKg = currentKg
            self.initialReps = currentReps
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
            
            self.initialKg = currentKg
            self.initialReps = currentReps
            self.initialIsCompleted = set.isCompleted
        }
    }
    
    func adjustKg(by amount: Double) {
        kg = clamp(kg + amount, in: 0...500)
    }
    
    func adjustReps(by amount: Int) {
        reps = Int(clamp(Double(reps + amount), in: 0...100))
    }
    
    func handleDone(dismiss: () -> Void) {
        let kgChanged = kg != initialKg
        let repsChanged = reps != initialReps
        let completionChanged = isCompleted != initialIsCompleted
        
        if kgChanged || repsChanged {
            store.updateSetValues(
                exerciseID: exerciseID,
                setID: setID,
                kg: Decimal(kg),
                reps: reps
            )
        }
        
        if completionChanged {
            store.toggleSetCompletion(
                exerciseID: exerciseID,
                setID: setID,
                isCompleted: isCompleted
            )
        }
        
        dismiss()
    }
    
    private func clamp(_ value: Double, in range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
