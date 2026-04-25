import Foundation

enum ProgressionMetric: String, CaseIterable, Identifiable {
    case weight = "Weight"
    case volume = "Volume"
    case oneRepMax = "1RM"
    case pace = "Pace"
    case distance = "Distance"
    case calories = "Calories"
    
    var id: String { self.rawValue }
    
    var unit: String {
        switch self {
        case .weight, .volume, .oneRepMax:
            return "kg" // TODO: Support lbs based on user settings
        case .pace:
            return "min/km"
        case .distance:
            return "km"
        case .calories:
            return "kcal"
        }
    }
}

struct ProgressionDataPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    let metric: ProgressionMetric
}
