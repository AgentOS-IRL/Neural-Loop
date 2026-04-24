import SwiftUI

struct WorkoutTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: WorkoutTemplateEditorViewModel
    @State private var isLibraryPresented = false
    @State private var previewGallery: ExerciseMediaGallery?
    private let onSaved: () -> Void

    init(
        mode: WorkoutTemplateEditorMode,
        dataManager: (any WorkoutTemplateEditingDataManaging)? = nil,
        generatedRoutine: WorkoutRoutineGenerationPayload? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(
            wrappedValue: WorkoutTemplateEditorViewModel(
                mode: mode,
                dataManager: dataManager ?? DBManager.newInstance(),
                generatedRoutine: generatedRoutine
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        templateForm
                        templateContent
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(viewModel.mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
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
            .sheet(isPresented: $isLibraryPresented) {
                ExerciseLibrarySelectionSheet(
                    items: viewModel.availableExercises,
                    initiallySelectedExerciseIDs: viewModel.selectedExerciseIDs,
                    onAdd: { selections in
                        viewModel.syncExercises(with: selections)
                    }
                )
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.mode.headerTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Create a reusable routine. This does not create a workout log.")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private var templateForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Routine Name")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                TextField("Routine name", text: $viewModel.title)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .rounded, weight: .medium))
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

            VStack(alignment: .leading, spacing: 10) {
                Text("Notes")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                TextEditor(text: $viewModel.notes)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(10)
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
    }

    @ViewBuilder
    private var templateContent: some View {
        if viewModel.isLoading {
            loadingState
        } else if viewModel.exerciseDrafts.isEmpty {
            if let errorMessage = viewModel.errorMessage {
                errorState(message: errorMessage)
            } else {
                emptyState
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.subtitleText)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(message: errorMessage)
                }

                ForEach(Array(viewModel.exerciseDrafts.enumerated()), id: \.element.id) { index, draft in
                    WorkoutTemplateExerciseCard(
                        draft: draft,
                        canMoveUp: index > 0,
                        canMoveDown: index < viewModel.exerciseDrafts.count - 1,
                        onMoveUp: {
                            viewModel.moveExercise(id: draft.id, by: -1)
                        },
                        onMoveDown: {
                            viewModel.moveExercise(id: draft.id, by: 1)
                        },
                        onRemove: {
                            viewModel.removeExercise(id: draft.id)
                        },
                        onTargetSetsChange: { value in
                            viewModel.updateTargetSets(id: draft.id, value: value)
                        },
                        onTargetRepsChange: { value in
                            viewModel.updateTargetReps(id: draft.id, value: value)
                        },
                        onDurationChange: { value in
                            viewModel.updateDuration(id: draft.id, value: value)
                        },
                        onRestSecondsChange: { value in
                            viewModel.updateRestSeconds(id: draft.id, value: value)
                        },
                        onPreviewRequested: { gallery in
                            previewGallery = gallery
                        }
                    )
                }
            }
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            errorBanner(message: message)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.textPrimary)

            Text("Loading routine")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No exercises yet")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Add exercises to build this routine.")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                isLibraryPresented = true
            } label: {
                Label("Add Exercises", systemImage: "plus")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .frame(minWidth: 180, minHeight: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background {
                Capsule()
                    .fill(AppTheme.accentGradient)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(.horizontal, 20)
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
                isLibraryPresented = true
            } label: {
                Label("Add Exercises", systemImage: "plus")
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
            .disabled(viewModel.isLoading)

            Button {
                Task {
                    let didSave = await viewModel.save()
                    if didSave {
                        dismiss()
                        onSaved()
                    }
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    Text("Save")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background {
                Capsule()
                    .fill(viewModel.canSave ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(Color.gray.opacity(0.45)))
            }
            .disabled(!viewModel.canSave)
        }
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private func errorBanner(message: String) -> some View {
        Text(message)
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.errorTint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.errorTint.opacity(0.10))
            }
    }
}

private extension WorkoutTemplateEditorMode {
    var navigationTitle: String {
        switch self {
        case .create:
            return "New Routine"
        case .edit:
            return "Edit Routine"
        }
    }

    var headerTitle: String {
        switch self {
        case .create:
            return "New Routine"
        case .edit:
            return "Edit Routine"
        }
    }
}

#Preview {
    WorkoutTemplateEditorView(mode: .create)
}
