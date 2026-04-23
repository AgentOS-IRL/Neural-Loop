import SwiftUI

struct WorkoutRoutineGenerationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator: WorkoutRoutineGenerationCodexCoordinator
    @State private var prompt: String = ""
    @State private var generationTask: Task<Void, Never>?
    private let onGenerated: (WorkoutRoutineGenerationPayload) -> Void

    init(
        model: UnifiedDataModel,
        dataManager: any WorkoutTemplateReadingDataManaging,
        onGenerated: @escaping (WorkoutRoutineGenerationPayload) -> Void
    ) {
        _coordinator = StateObject(
            wrappedValue: WorkoutRoutineGenerationCodexCoordinator(
                model: model,
                dataManager: dataManager
            )
        )
        self.onGenerated = onGenerated
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        promptCard
                        statusCard
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Generate Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        cancelGeneration()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .onDisappear {
                cancelGeneration()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout Routine Generator")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Describe the routine you want. Codex will turn it into a workout template and the app will drop any exercises that do not exist in the catalog.")
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

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prompt")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            TextEditor(text: $prompt)
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
    }

    @ViewBuilder
    private var statusCard: some View {
        if let errorMessage = coordinator.errorMessage {
            statusBanner(
                title: "Generation failed",
                message: errorMessage,
                color: AppTheme.errorTint
            )
        } else if let statusMessage = coordinator.statusMessage {
            statusBanner(
                title: "Status",
                message: statusMessage,
                color: AppTheme.textPrimary
            )
        } else if !coordinator.canGenerate {
            statusBanner(
                title: "LLM unavailable",
                message: "Enable Codex access before generating a routine.",
                color: AppTheme.textSecondary
            )
        }
    }

    private func statusBanner(title: String, message: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(color)

            Text(message)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
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

    private var bottomActionBar: some View {
        let canGenerateRoutine = coordinator.canGenerate && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return HStack(spacing: 12) {
            Button {
                generationTask?.cancel()
                generationTask = Task {
                    guard let routine = await coordinator.generateRoutine(prompt: prompt) else {
                        return
                    }

                    guard !Task.isCancelled else {
                        return
                    }

                    await MainActor.run {
                        guard !Task.isCancelled else {
                            return
                        }

                        onGenerated(routine)
                        dismiss()
                    }
                }
            } label: {
                if coordinator.isGenerating {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    Text("Generate Routine")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background {
                Capsule()
                    .fill(canGenerateRoutine ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(Color.gray.opacity(0.45)))
            }
            .disabled(!canGenerateRoutine)
        }
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
    }
}

#Preview {
    WorkoutRoutineGenerationView(
        model: UnifiedDataModel(autoStart: false),
        dataManager: DBManager.newInstance()
    ) { _ in }
}
