import Combine
import Foundation

@MainActor
final class ExerciseLibrarySelectionViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedMuscleID: Int64?
    @Published var selectedEquipmentName: String?
    @Published private(set) var selectedIDs: Set<Int64>

    let items: [ExerciseLibraryItem]

    init(items: [ExerciseLibraryItem], initiallySelectedExerciseIDs: Set<Int64>) {
        self.items = items
        selectedIDs = initiallySelectedExerciseIDs
    }

    var equipmentFilterTitle: String {
        selectedEquipmentName ?? "All equipment"
    }

    var muscleFilterTitle: String {
        guard let selectedMuscleID,
              let selectedMuscle = muscleOptions.first(where: { $0.id == selectedMuscleID }) else {
            return "All muscles"
        }

        return selectedMuscle.name
    }

    var muscleOptions: [ExerciseLibraryMuscleOption] {
        let optionsByID = Dictionary(
            items.flatMap(\.muscles).map { muscle in
                (muscle.muscleID, ExerciseLibraryMuscleOption(id: muscle.muscleID, name: muscle.muscleName))
            },
            uniquingKeysWith: { existing, _ in existing }
        )

        return optionsByID.values.sorted {
            switch $0.name.localizedCaseInsensitiveCompare($1.name) {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                return $0.id < $1.id
            @unknown default:
                return $0.id < $1.id
            }
        }
    }

    var equipmentNames: [String] {
        Array(Set(items.map(\.equipmentName))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var filteredSections: [ExerciseLibrarySection] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredItems = items.filter { item in
            let matchesSearch = trimmedSearch.isEmpty
                || item.name.localizedCaseInsensitiveContains(trimmedSearch)
                || item.equipmentName.localizedCaseInsensitiveContains(trimmedSearch)
                || item.muscles.contains(where: { $0.muscleName.localizedCaseInsensitiveContains(trimmedSearch) })
            let matchesMuscle: Bool
            if let selectedMuscleID {
                matchesMuscle = item.muscles.contains(where: { $0.muscleID == selectedMuscleID })
            } else {
                matchesMuscle = true
            }
            let matchesEquipment = selectedEquipmentName == nil || item.equipmentName == selectedEquipmentName
            return matchesSearch && matchesMuscle && matchesEquipment
        }

        if let selectedMuscleID {
            return groupedBySelectedMuscle(filteredItems, selectedMuscleID: selectedMuscleID)
        }

        let grouped = Dictionary(grouping: filteredItems) { item in
            guard let firstCharacter = item.name.trimmingCharacters(in: .whitespacesAndNewlines).first else {
                return "#"
            }

            return String(firstCharacter).uppercased()
        }

        return grouped.keys.sorted().map { title in
            ExerciseLibrarySection(
                title: title,
                items: (grouped[title] ?? []).sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            )
        }
    }

    var selectedItems: [ExerciseLibraryItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    func toggleSelection(for item: ExerciseLibraryItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func selectMuscle(_ id: Int64?) {
        selectedMuscleID = id
    }

    func selectEquipment(_ name: String?) {
        selectedEquipmentName = name
    }

    private func groupedBySelectedMuscle(
        _ filteredItems: [ExerciseLibraryItem],
        selectedMuscleID: Int64
    ) -> [ExerciseLibrarySection] {
        let roleOrder: [ExerciseLibrarySelectedMuscleRole] = [.primary, .secondary]

        return roleOrder.compactMap { role in
            let sectionItems = filteredItems
                .filter { item in
                    selectedMuscleRole(for: item, selectedMuscleID: selectedMuscleID) == role
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }

            guard !sectionItems.isEmpty else {
                return nil
            }

            return ExerciseLibrarySection(title: role.sectionTitle, items: sectionItems)
        }
    }

    private func selectedMuscleRole(
        for item: ExerciseLibraryItem,
        selectedMuscleID: Int64
    ) -> ExerciseLibrarySelectedMuscleRole? {
        guard let muscle = item.muscles.first(where: { $0.muscleID == selectedMuscleID }) else {
            return nil
        }

        return muscle.isPrimary ? .primary : .secondary
    }
}

struct ExerciseLibraryMuscleOption: Identifiable, Equatable {
    let id: Int64
    var name: String
}

private enum ExerciseLibrarySelectedMuscleRole {
    case primary
    case secondary

    var sectionTitle: String {
        switch self {
        case .primary:
            return "Primary"
        case .secondary:
            return "Secondary"
        }
    }
}
