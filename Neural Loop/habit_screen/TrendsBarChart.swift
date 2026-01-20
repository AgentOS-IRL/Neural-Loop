
import SwiftUI
import Charts

enum TrendFrequency: String, CaseIterable, Identifiable {
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
    func get_frequency() -> Calendar.RecurrenceRule.Frequency {
        switch self {
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        }
        
    }
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Float
}

func makeTrendPoints(from data: [Date: Float]) -> [TrendPoint] {
    data
        .map { TrendPoint(date: $0.key, value: $0.value) }
        .sorted { $0.date < $1.date }
}

struct TrendsBarChart: View {

    let data: [Date: Float]
    let frequency: TrendFrequency

    private var points: [TrendPoint] {
        makeTrendPoints(from: data)
    }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Period", point.date),
                y: .value("Value", point.value)
            )
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(xAxisLabel(for: date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
        .animation(.easeInOut, value: frequency)
    }

    private func xAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch frequency {
        case .weekly:
            formatter.dateFormat = "dd/MM"   // e.g. 21/12
        case .monthly:
            formatter.dateFormat = "MMM"     // e.g. Jan
        }
        return formatter.string(from: date)
    }
}
