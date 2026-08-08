import SwiftUI

struct StrengthVolumeCard: View {
    let summary: FitnessAnalysisSummary
    let isLoading: Bool
    @State private var selectedMetric: MuscleWheelMetric = .totalVolume

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: selectedMetric.iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(selectedMetric.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Menu {
                    ForEach(MuscleWheelMetric.allCases) { metric in
                        Button {
                            selectedMetric = metric
                        } label: {
                            Label(metric.title, systemImage: metric == selectedMetric ? "checkmark" : metric.iconSystemName)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change analysis metric")
            }

            if isLoading && !summary.hasStrengthData {
                loadingAnalysis
            } else {
                MuscleVolumeWheel(
                    muscleVolumes: selectedMetric.muscleVolumes(from: summary),
                    valueFormatter: selectedMetric.valueText
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 340, alignment: .topLeading)
        .background {
            AnalysisCardBackground()
        }
    }

    private var loadingAnalysis: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.textPrimary)

            Text("Loading strength analysis")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
}

enum MuscleWheelMetric: String, CaseIterable, Identifiable {
    case totalVolume
    case workoutFrequency

    var id: String { rawValue }

    var title: String {
        switch self {
        case .totalVolume: return "Total Volume"
        case .workoutFrequency: return "Workout Frequency"
        }
    }

    var iconSystemName: String {
        switch self {
        case .totalVolume: return "scalemass.fill"
        case .workoutFrequency: return "calendar.badge.clock"
        }
    }

    func muscleVolumes(from summary: FitnessAnalysisSummary) -> [FitnessMuscleVolume] {
        switch self {
        case .totalVolume: return summary.muscleVolumes
        case .workoutFrequency: return summary.muscleFrequencies
        }
    }

    func valueText(_ value: Double) -> String {
        switch self {
        case .totalVolume:
            let rounded = Int(value.rounded())

            if rounded >= 1000 {
                let thousands = Double(rounded) / 1000
                return "\(thousands.formatted(.number.precision(.fractionLength(1))))k kg"
            }

            return "\(rounded) kg"
        case .workoutFrequency:
            return "\(Int(value.rounded()))x"
        }
    }
}

struct MuscleVolumeWheel: View {
    let muscleVolumes: [FitnessMuscleVolume]
    let valueFormatter: (Double) -> String
    private let ringCount = 4
    private let ringWidth: CGFloat = 10
    private let ringGap: CGFloat = 5
    private let innerRingRadius: CGFloat = 28
    private let sectorDegrees = 60.0
    private let sectorGapDegrees = 12.0

    private var maxMuscleVolume: Double {
        muscleVolumes.map(\.volume).max() ?? 0
    }

    private var hasData: Bool {
        maxMuscleVolume > 0
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                centerWheel
                    .frame(width: 166, height: 166)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                ForEach(Array(muscleVolumes.enumerated()), id: \.element.id) { index, muscle in
                    muscleLabel(muscle)
                        .position(position(for: index, in: proxy.size))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 250)
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }

    private var centerWheel: some View {
        ZStack {
            ForEach(Array(muscleVolumes.enumerated()), id: \.element.id) { index, muscle in
                ForEach(0..<ringCount, id: \.self) { ringIndex in
                    let angles = angleRange(for: muscle, fallbackIndex: index)
                    let radius = radius(for: ringIndex)

                    MuscleVolumeWheelArc(
                        radius: radius,
                        startAngle: angles.start,
                        endAngle: angles.end
                    )
                    .stroke(
                        AppTheme.textSecondary.opacity(0.14),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )

                    if activeFraction(for: muscle, ringIndex: ringIndex) > 0 {
                        MuscleVolumeWheelArc(
                            radius: radius,
                            startAngle: angles.start,
                            endAngle: angles.end
                        )
                        .stroke(
                            AppTheme.accentColor.opacity(activeOpacity(for: muscle, ringIndex: ringIndex)),
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                    }
                }
            }

            Circle()
                .fill(AppTheme.textPrimary.opacity(0.05))
                .frame(width: 54, height: 54)
        }
        .opacity(hasData ? 0.92 : 0.42)
    }

    private func radius(for ringIndex: Int) -> CGFloat {
        innerRingRadius + CGFloat(ringIndex) * (ringWidth + ringGap)
    }

    private func angleRange(
        for muscle: FitnessMuscleVolume,
        fallbackIndex: Int
    ) -> (start: Angle, end: Angle) {
        let center = sectorCenterAngle(for: muscle, fallbackIndex: fallbackIndex)
        let halfSpan = (sectorDegrees - sectorGapDegrees) / 2

        return (
            start: .degrees(center - halfSpan),
            end: .degrees(center + halfSpan)
        )
    }

    private func sectorCenterAngle(
        for muscle: FitnessMuscleVolume,
        fallbackIndex: Int
    ) -> Double {
        switch muscle.name {
        case "Chest": return -90
        case "Back": return -30
        case "Legs": return 30
        case "Shoulders": return 90
        case "Core": return 150
        case "Arms": return 210
        default: return -90 + Double(fallbackIndex) * sectorDegrees
        }
    }

    private func activeFraction(
        for muscle: FitnessMuscleVolume,
        ringIndex: Int
    ) -> Double {
        guard maxMuscleVolume > 0, muscle.volume > 0 else { return 0 }

        let ratio = min(max(muscle.volume / maxMuscleVolume, 0), 1)
        let lowerBound = Double(ringIndex) / Double(ringCount)
        let upperBound = Double(ringIndex + 1) / Double(ringCount)

        guard ratio > lowerBound else { return 0 }
        return min((ratio - lowerBound) / (upperBound - lowerBound), 1)
    }

    private func activeOpacity(
        for muscle: FitnessMuscleVolume,
        ringIndex: Int
    ) -> Double {
        0.22 + (activeFraction(for: muscle, ringIndex: ringIndex) * 0.42)
    }

    private func muscleLabel(_ muscle: FitnessMuscleVolume) -> some View {
        VStack(spacing: 2) {
            Text(valueFormatter(muscle.volume))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(muscle.name)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(width: 116)
        .accessibilityElement(children: .combine)
    }

    private func position(for index: Int, in size: CGSize) -> CGPoint {
        let fractional: CGPoint
        switch index {
        case 0: fractional = CGPoint(x: 0.50, y: 0.09)
        case 1: fractional = CGPoint(x: 0.78, y: 0.28)
        case 2: fractional = CGPoint(x: 0.78, y: 0.78)
        case 3: fractional = CGPoint(x: 0.22, y: 0.78)
        case 4: fractional = CGPoint(x: 0.50, y: 0.95)
        default: fractional = CGPoint(x: 0.22, y: 0.28)
        }

        return CGPoint(x: fractional.x * size.width, y: fractional.y * size.height)
    }
}

struct MuscleVolumeWheelArc: Shape {
    let radius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

struct StrengthProgressionCard: View {
    let summary: FitnessAnalysisSummary
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("Strength Progression")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if isLoading && summary.progressionPoints.isEmpty {
                ProgressView()
                    .tint(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 156)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 156)
            } else if summary.progressionPoints.isEmpty {
                emptyProgression
            } else {
                progressionChart
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .background {
            AnalysisCardBackground()
        }
    }

    private var emptyProgression: some View {
        ZStack {
            progressionSkeleton

            VStack(spacing: 8) {
                Text("No progression data")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("No strength activity recorded in the last 30 days.")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, minHeight: 156)
    }

    private var progressionSkeleton: some View {
        VStack(spacing: 18) {
            ForEach(0..<4, id: \.self) { row in
                HStack {
                    Capsule()
                        .fill(AppTheme.textSecondary.opacity(0.08))
                        .frame(width: row.isMultiple(of: 2) ? 96 : 170, height: 12)

                    Spacer()

                    Capsule()
                        .fill(AppTheme.textSecondary.opacity(0.08))
                        .frame(width: row.isMultiple(of: 2) ? 172 : 96, height: 12)
                }
            }
        }
    }

    private var progressionChart: some View {
        GeometryReader { proxy in
            let maxVolume = max(summary.progressionPoints.map(\.volume).max() ?? 1, 1)
            let barWidth = max((proxy.size.width - 36) / CGFloat(max(summary.progressionPoints.count, 1)), 5)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(summary.progressionPoints) { point in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(AppTheme.accentGradient)
                        .frame(
                            width: barWidth,
                            height: max(12, proxy.size.height * CGFloat(point.volume / maxVolume))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(height: 156)
        .accessibilityLabel("Strength progression chart")
    }
}

struct AnalysisCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(AppTheme.cardGradient)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 12, y: 8)
    }
}


