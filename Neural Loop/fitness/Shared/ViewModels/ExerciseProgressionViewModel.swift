import Foundation
import Combine

@MainActor
class ExerciseProgressionViewModel: ObservableObject {
    let exerciseId: Int64
    let exerciseName: String
    let exerciseType: ExerciseType
    private let dataManager: WorkoutDataManaging

    @Published var dataPoints: [ProgressionDataPoint] = []
    @Published var selectedMetric: ProgressionMetric = .weight
    @Published var isLoading = false
    @Published var availableMetrics: [ProgressionMetric] = []

    init(exerciseId: Int64, exerciseName: String, exerciseType: ExerciseType, dataManager: WorkoutDataManaging) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.exerciseType = exerciseType
        self.dataManager = dataManager
        
        self.availableMetrics = exerciseType.isRepBased ? [.weight, .volume, .oneRepMax] : [.pace, .distance, .calories]
        self.selectedMetric = self.availableMetrics.first ?? .weight
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let results = try await dataManager.fetchExerciseProgression(exerciseId: exerciseId)
            transformData(results: results)
        } catch {
            print("Error loading progression data: \(error)")
        }
    }

    private func transformData(results: [ExerciseProgressionResult]) {
        // Group by date to find best/total for each day
        let grouped = Dictionary(grouping: results) { result in
            Calendar.current.startOfDay(for: result.date)
        }
        
        var points: [ProgressionDataPoint] = []
        
        for (date, dayResults) in grouped {
            for metric in availableMetrics {
                if let value = calculateValue(for: metric, results: dayResults) {
                    points.append(ProgressionDataPoint(date: date, value: value, metric: metric))
                }
            }
        }
        
        self.dataPoints = points.sorted { $0.date < $1.date }
    }

    func calculateValue(for metric: ProgressionMetric, results: [ExerciseProgressionResult]) -> Double? {
        switch metric {
        case .weight:
            let weights = results.compactMap { $0.weight }.map { NSDecimalNumber(decimal: $0).doubleValue }
            return weights.max()
        case .volume:
            let volume = results.reduce(0.0) { sum, result in
                let w = NSDecimalNumber(decimal: result.weight ?? 0).doubleValue
                let r = Double(result.reps ?? 0)
                return sum + (w * r)
            }
            return volume > 0 ? volume : nil
        case .oneRepMax:
            let oneRepMaxes = results.compactMap { result -> Double? in
                guard let w = result.weight, let r = result.reps, r > 0 else { return nil }
                return calculateOneRepMax(weight: NSDecimalNumber(decimal: w).doubleValue, reps: r)
            }
            return oneRepMaxes.max()
        case .pace:
            // Average pace for the day
            let totalDistance = results.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.distance_meters ?? 0).doubleValue }
            let totalDuration = results.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.duration_minutes ?? 0).doubleValue }
            guard totalDistance > 0 else { return nil }
            return totalDuration / (totalDistance / 1000.0) // min/km
        case .distance:
            let distance = results.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.distance_meters ?? 0).doubleValue } / 1000.0
            return distance > 0 ? distance : nil
        case .calories:
            let calories = results.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.calories ?? 0).doubleValue }
            return calories > 0 ? calories : nil
        }
    }

    func calculateOneRepMax(weight: Double, reps: Int) -> Double {
        // Brzycki formula: weight * (36 / (37 - reps))
        // Only valid for reps < 37. If reps >= 37, it becomes undefined or negative.
        guard reps > 0 else { return 0 }
        if reps == 1 { return weight }
        let denominator = 37.0 - Double(min(reps, 36))
        return weight * (36.0 / denominator)
    }
}
