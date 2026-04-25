import SwiftUI
import Charts

struct ExerciseProgressionView: View {
    @StateObject var viewModel: ExerciseProgressionViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.dataPoints.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            metricPicker
                                .padding(.top, 16)
                            
                            chartSection
                            
                            statsSummary
                                .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.exerciseName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Progression")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(AppTheme.textSecondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textSecondary.opacity(0.5))
            Text("No historical data yet")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text("Complete workouts for this exercise to see your progress here.")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var metricPicker: some View {
        Picker("Metric", selection: $viewModel.selectedMetric) {
            ForEach(viewModel.availableMetrics) { metric in
                Text(metric.rawValue).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
    }

    private var chartSection: some View {
        let filteredPoints = viewModel.dataPoints.filter { $0.metric == viewModel.selectedMetric }
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trend")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 24)
            
            Chart {
                ForEach(filteredPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AppTheme.accentColor)
                    
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(AppTheme.accentColor)
                    
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accentColor.opacity(0.3), AppTheme.accentColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(doubleValue, specifier: "%.1f")")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(format: .dateTime.month().day())
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 20)
        .background(
            AppTheme.cardGradient
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius)
                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private var statsSummary: some View {
        let filteredPoints = viewModel.dataPoints.filter { $0.metric == viewModel.selectedMetric }
        let current = filteredPoints.last?.value ?? 0
        let values = filteredPoints.map { $0.value }
        let best = viewModel.selectedMetric == .pace ? (values.min() ?? 0) : (values.max() ?? 0)
        
        return HStack(spacing: 16) {
            statCard(title: "Current", value: current, unit: viewModel.selectedMetric.unit)
            statCard(title: "All-Time Best", value: best, unit: viewModel.selectedMetric.unit)
        }
        .padding(.horizontal, 24)
    }

    private func statCard(title: String, value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(value, specifier: "%.1f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.textPrimary)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            AppTheme.cardGradient
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.borderGradient, lineWidth: 1)
                )
        )
    }
}
