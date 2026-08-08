import Foundation
import Combine
import SwiftUI

@MainActor
final class WatchSetEntryViewModel: ObservableObject {
    @Published var kg: Double = 0
    @Published var reps: Int = 0
    @Published var durationMinutes: Double = 0
    @Published var distanceKilometers: Double = 0
    @Published var calories: Double = 0
    @Published var isCompleted: Bool = false
    
    private var initialKg: Decimal?
    private var initialReps: Int?
    private var initialDurationMinutes: Decimal?
    private var initialDistanceKilometers: Decimal?
    private var initialCalories: Decimal?
    private var initialIsCompleted: Bool = false
    private var kgEdited = false
    private var repsEdited = false
    private var durationEdited = false
    private var distanceEdited = false
    private var caloriesEdited = false
    
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
            self.durationMinutes = (set.values.durationMinutes as NSDecimalNumber?)?.doubleValue ?? 0
            self.distanceKilometers = (set.values.distanceKilometers as NSDecimalNumber?)?.doubleValue ?? 0
            self.calories = (set.values.calories as NSDecimalNumber?)?.doubleValue ?? 0
            
            self.initialKg = set.values.kg
            self.initialReps = set.values.reps
            self.initialDurationMinutes = set.values.durationMinutes
            self.initialDistanceKilometers = set.values.distanceKilometers
            self.initialCalories = set.values.calories
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
            self.durationMinutes = (set.values.durationMinutes as NSDecimalNumber?)?.doubleValue ?? 0
            self.distanceKilometers = (set.values.distanceKilometers as NSDecimalNumber?)?.doubleValue ?? 0
            self.calories = (set.values.calories as NSDecimalNumber?)?.doubleValue ?? 0
            
            self.initialKg = set.values.kg
            self.initialReps = set.values.reps
            self.initialDurationMinutes = set.values.durationMinutes
            self.initialDistanceKilometers = set.values.distanceKilometers
            self.initialCalories = set.values.calories
            self.initialIsCompleted = set.isCompleted
            self.kgEdited = false
            self.repsEdited = false
            self.durationEdited = false
            self.distanceEdited = false
            self.caloriesEdited = false
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

    func setDuration(_ value: Double) {
        durationMinutes = clamp(value, in: 0...600)
        durationEdited = true
    }

    func setDistance(_ value: Double) {
        distanceKilometers = clamp(value, in: 0...500)
        distanceEdited = true
    }

    func setCalories(_ value: Double) {
        calories = clamp(value, in: 0...10_000)
        caloriesEdited = true
    }

    func useSuggestion(_ values: WorkoutSetValuesSnapshot) {
        if let suggestedKg = values.kg {
            kg = (suggestedKg as NSDecimalNumber).doubleValue
            kgEdited = true
        }
        if let suggestedReps = values.reps {
            reps = suggestedReps
            repsEdited = true
        }
        if let duration = values.durationMinutes {
            durationMinutes = (duration as NSDecimalNumber).doubleValue
            durationEdited = true
        }
        if let distance = values.distanceKilometers {
            distanceKilometers = (distance as NSDecimalNumber).doubleValue
            distanceEdited = true
        }
        if let suggestedCalories = values.calories {
            calories = (suggestedCalories as NSDecimalNumber).doubleValue
            caloriesEdited = true
        }
    }
    
    // MARK: - Separated Actions
    
    /// Saves only weight/rep values without changing completion state.
    func commitValues() {
        let kgChanged = kgEdited && Decimal(kg) != initialKg
        let repsChanged = repsEdited && reps != initialReps
        let durationChanged = durationEdited && Decimal(durationMinutes) != initialDurationMinutes
        let distanceChanged = distanceEdited && Decimal(distanceKilometers) != initialDistanceKilometers
        let caloriesChanged = caloriesEdited && Decimal(calories) != initialCalories
        
        if kgChanged || repsChanged || durationChanged || distanceChanged || caloriesChanged {
            store.updateSetValues(
                exerciseID: exerciseID,
                setID: setID,
                kg: kgChanged ? Decimal(kg) : nil,
                reps: repsChanged ? reps : nil,
                durationMinutes: durationChanged ? Decimal(durationMinutes) : nil,
                distanceKilometers: distanceChanged ? Decimal(distanceKilometers) : nil,
                calories: caloriesChanged ? Decimal(calories) : nil
            )
            // Update initial values so subsequent saves detect correctly
            if kgChanged { initialKg = Decimal(kg) }
            if repsChanged { initialReps = reps }
            if durationChanged { initialDurationMinutes = Decimal(durationMinutes) }
            if distanceChanged { initialDistanceKilometers = Decimal(distanceKilometers) }
            if caloriesChanged { initialCalories = Decimal(calories) }
            kgEdited = false
            repsEdited = false
            durationEdited = false
            distanceEdited = false
            caloriesEdited = false
        }
    }
    
    /// Saves values and marks the set as completed.
    @discardableResult
    func commitAndComplete(isCardio: Bool = false) -> Bool {
        if isCardio {
            guard durationMinutes > 0 || distanceKilometers > 0 || calories > 0 else { return false }
        } else {
            guard reps > 0 else { return false }
        }
        commitValues()
        if !isCompleted {
            isCompleted = true
            store.toggleSetCompletion(
                exerciseID: exerciseID,
                setID: setID,
                isCompleted: true
            )
        }
        return true
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
