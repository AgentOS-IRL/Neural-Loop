import Combine
import Foundation

@MainActor
final class ExerciseLibrarySelectionViewModel: ObservableObject {
    @Published var searchText = ""
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
            let matchesEquipment = selectedEquipmentName == nil || item.equipmentName == selectedEquipmentName
            return matchesSearch && matchesEquipment
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

    func selectEquipment(_ name: String?) {
        selectedEquipmentName = name
    }
}
