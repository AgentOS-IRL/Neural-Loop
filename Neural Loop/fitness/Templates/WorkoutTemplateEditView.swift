import SwiftUI

struct WorkoutTemplateEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WorkoutTemplateEditViewModel
    private let onSaved: () -> Void

    init(
        template: WorkoutTemplateSummary,
        dataManager: any WorkoutRoutineReading & WorkoutRoutineWriting,
        onSaved: @escaping () -> Void = {}
    ) {
        self._viewModel = StateObject(
            wrappedValue: WorkoutTemplateEditViewModel(summary: template, dataManager: dataManager)
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
                        header
                        formContent
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Routine")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Rename the routine and update its notes without creating a workout log.")
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

    @ViewBuilder
    private var formContent: some View {
        if viewModel.isLoading {
            loadingState
        } else {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage = viewModel.errorMessage {
                    errorBanner(message: errorMessage)
                }

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
                        .frame(minHeight: 180)
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

                Button {
                    Task { await save() }
                } label: {
                    Text(viewModel.isSaving ? "Saving..." : "Save Changes")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background {
                    Capsule()
                        .fill(viewModel.canSave ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(Color.gray.opacity(0.45)))
                }
                .disabled(!viewModel.canSave)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.textPrimary)

            Text("Loading routine")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
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

    private func save() async {
        let didSave = await viewModel.save()
        guard didSave else {
            return
        }

        dismiss()
        onSaved()
    }
}

#Preview {
    WorkoutTemplateEditView(
        template: WorkoutTemplateSummary(id: 1, title: "Push Day", exerciseCount: 3, setCount: 9),
        dataManager: DBManager.newInstance()
    )
}
