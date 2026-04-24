import SwiftUI

struct ExerciseLibrarySelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: ExerciseLibrarySelectionViewModel
    @State private var previewGallery: ExerciseMediaGallery?

    let onAdd: ([ExerciseLibraryItem]) -> Void

    init(
        items: [ExerciseLibraryItem],
        initiallySelectedExerciseIDs: Set<Int64>,
        onAdd: @escaping ([ExerciseLibraryItem]) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ExerciseLibrarySelectionViewModel(
                items: items,
                initiallySelectedExerciseIDs: initiallySelectedExerciseIDs
            )
        )
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchAndFilters

                if viewModel.filteredSections.isEmpty {
                    emptyState
                } else {
                    exerciseList
                }
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $previewGallery) { gallery in
                ExerciseMediaPreviewSheet(gallery: gallery, allowsMotion: !reduceMotion)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onAdd(viewModel.selectedItems)
                        dismiss()
                    }
                    .disabled(viewModel.selectedIDs.isEmpty)
                }
            }
        }
    }

    private var searchAndFilters: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textSecondary)

                TextField("Search", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardGradient)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
            }

            HStack(spacing: 10) {
                Menu {
                    Button("All groups", action: {})
                } label: {
                    filterLabel("All groups", systemImage: "line.3.horizontal.decrease.circle")
                }

                Menu {
                    Button("All equipment") {
                        viewModel.selectEquipment(nil)
                    }

                    ForEach(viewModel.equipmentNames, id: \.self) { equipmentName in
                        Button(equipmentName) {
                            viewModel.selectEquipment(equipmentName)
                        }
                    }
                } label: {
                    filterLabel(viewModel.equipmentFilterTitle, systemImage: "dumbbell")
                }
            }
        }
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var exerciseList: some View {
        List {
            ForEach(viewModel.filteredSections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        exerciseRow(item)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: AppTheme.Metrics.screenPadding, bottom: 6, trailing: AppTheme.Metrics.screenPadding))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text("No exercises found")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func exerciseRow(_ item: ExerciseLibraryItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ExerciseMediaView(
                exerciseName: item.name,
                mode: .thumbnail,
                onPreviewRequested: { gallery in
                    previewGallery = gallery
                }
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    pillLabel(item.equipmentName, systemImage: "dumbbell")
                    pillLabel(item.isRepBased ? "Reps" : "Duration", systemImage: item.isRepBased ? "repeat" : "timer")
                }
            }

            Spacer(minLength: 8)

            Button {
                viewModel.toggleSelection(for: item)
            } label: {
                Image(systemName: viewModel.selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(viewModel.selectedIDs.contains(item.id) ? AppTheme.accentColor : AppTheme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.selectedIDs.contains(item.id) ? "Remove \(item.name)" : "Select \(item.name)")
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardGradient)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
    }

    private func pillLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
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

    private func filterLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        .foregroundStyle(AppTheme.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.sectionGradient)
        }
    }
}
