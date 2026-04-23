import SwiftUI

struct WorkoutTemplateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: WorkoutTemplateDetailViewModel
    @State private var isEditPresented = false
    @State private var previewGallery: ExerciseMediaGallery?
    private let onSaved: () -> Void

    init(
        template: WorkoutTemplateSummary,
        dataManager: (any WorkoutTemplateEditingDataManaging)? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        self._viewModel = StateObject(
            wrappedValue: WorkoutTemplateDetailViewModel(summary: template, dataManager: dataManager)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    header
                    showcaseStrip
                    content
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.top, 16)
            }
            .navigationTitle(viewModel.summary.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .sheet(item: $previewGallery) { gallery in
                ExerciseMediaPreviewSheet(gallery: gallery, allowsMotion: !reduceMotion)
            }
            .presentationDetents([.fraction(0.5), .large])
            .presentationDragIndicator(.visible)
            .sheet(isPresented: $isEditPresented) {
                WorkoutTemplateEditorView(
                    mode: .edit(viewModel.summary),
                    dataManager: viewModel.dataManager
                ) {
                    Task {
                        await viewModel.reload()
                        onSaved()
                    }
                }
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.summary.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(viewModel.summary.countText)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
    }

    private var showcaseStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(viewModel.rows.prefix(4))) { row in
                    ExerciseMediaView(
                        exerciseName: row.exerciseName,
                        mode: .thumbnail,
                        onPreviewRequested: { gallery in
                            previewGallery = gallery
                        }
                    )
                        .frame(width: 92, height: 92)
                }
            }
            .padding(.vertical, 2)
        }
        .opacity(viewModel.rows.isEmpty ? 0 : 1)
        .accessibilityHidden(viewModel.rows.isEmpty)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.rows.isEmpty {
            loadingState
        } else if let errorMessage = viewModel.errorMessage, viewModel.rows.isEmpty {
            errorState(message: errorMessage)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    ForEach(viewModel.rows) { row in
                        workoutRow(row)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    private func workoutRow(_ row: WorkoutTemplateExerciseRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ExerciseMediaView(
                exerciseName: row.exerciseName,
                mode: .thumbnail,
                onPreviewRequested: { gallery in
                    previewGallery = gallery
                }
            )
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 8) {
                Text(row.exerciseName)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    pillLabel(row.equipmentName, systemImage: "dumbbell")
                    pillLabel("Set \(row.orderIndex + 1)", systemImage: "number")
                }
            }

            Spacer(minLength: 12)

            Text(row.setText)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(AppTheme.accentGradient)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
    }

    private func pillLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.system(.caption, design: .rounded, weight: .semibold))
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(AppTheme.sectionGradient)
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
                isEditPresented = true
            } label: {
                Text("Edit")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textPrimary)
            .background {
                Capsule()
                    .fill(AppTheme.cardGradient)
            }
            .overlay {
                Capsule()
                    .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
            }

            Button {
                // Placeholder for the future workout-start flow.
            } label: {
                Text("Start")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background {
                Capsule()
                    .fill(AppTheme.accentGradient)
            }
        }
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.textPrimary)

            Text("Loading template details")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            errorBanner(message: message)

            Button("Retry") {
                Task {
                    await viewModel.reload()
                }
            }
            .buttonStyle(.plain)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardGradient)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
    }
}

#Preview {
    WorkoutTemplateDetailView(
        template: WorkoutTemplateSummary(id: 1, title: "Push Day", exerciseCount: 3, setCount: 9)
    )
}
