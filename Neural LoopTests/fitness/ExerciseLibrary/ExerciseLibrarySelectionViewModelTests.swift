import XCTest
@testable import Neural_Loop

@MainActor
final class ExerciseLibrarySelectionViewModelTests: XCTestCase {
    func testFiltersBySearchText() {
        let viewModel = ExerciseLibrarySelectionViewModel(items: items, initiallySelectedExerciseIDs: [])

        viewModel.searchText = "cable"

        XCTAssertEqual(viewModel.filteredSections.flatMap(\.items).map(\.name), ["Cable Row"])

        viewModel.searchText = "barbell"

        XCTAssertEqual(viewModel.filteredSections.flatMap(\.items).map(\.name), ["Back Squat", "Bench Press"])
    }

    func testFiltersByEquipment() {
        let viewModel = ExerciseLibrarySelectionViewModel(items: items, initiallySelectedExerciseIDs: [])

        viewModel.selectEquipment("Cable")

        XCTAssertEqual(viewModel.filteredSections.flatMap(\.items).map(\.name), ["Cable Row"])
        XCTAssertEqual(viewModel.equipmentFilterTitle, "Cable")
    }

    func testGroupsFilteredExercisesAlphabetically() {
        let viewModel = ExerciseLibrarySelectionViewModel(items: items, initiallySelectedExerciseIDs: [])

        let sections = viewModel.filteredSections

        XCTAssertEqual(sections.map(\.title), ["B", "C", "D"])
        XCTAssertEqual(sections[0].items.map(\.name), ["Back Squat", "Bench Press"])
    }

    func testToggleSelectionAddsAndRemovesExercise() {
        let viewModel = ExerciseLibrarySelectionViewModel(items: items, initiallySelectedExerciseIDs: [])
        let item = items[0]

        viewModel.toggleSelection(for: item)
        XCTAssertTrue(viewModel.selectedIDs.contains(item.id))

        viewModel.toggleSelection(for: item)
        XCTAssertFalse(viewModel.selectedIDs.contains(item.id))
    }

    func testSelectedItemsPreserveSourceOrder() {
        let viewModel = ExerciseLibrarySelectionViewModel(items: items, initiallySelectedExerciseIDs: [3, 1])

        XCTAssertEqual(viewModel.selectedItems.map(\.id), [1, 3])
    }

    func testSearchByMuscleName() {
        let itemsWithMuscles = [
            ExerciseLibraryItem(
                id: 1,
                name: "Bench Press",
                type: .repBased,
                equipmentID: 1,
                equipmentName: "Barbell",
                muscles: [
                    MuscleMetadata(muscleID: 1, muscleName: "Chest", isPrimary: true),
                    MuscleMetadata(muscleID: 2, muscleName: "Triceps", isPrimary: false)
                ]
            ),
            ExerciseLibraryItem(
                id: 2,
                name: "Squat",
                type: .repBased,
                equipmentID: 1,
                equipmentName: "Barbell",
                muscles: [
                    MuscleMetadata(muscleID: 3, muscleName: "Quads", isPrimary: true)
                ]
            )
        ]
        let viewModel = ExerciseLibrarySelectionViewModel(items: itemsWithMuscles, initiallySelectedExerciseIDs: [])

        viewModel.searchText = "chest"
        XCTAssertEqual(viewModel.filteredSections.flatMap(\.items).map(\.name), ["Bench Press"])

        viewModel.searchText = "triceps"
        XCTAssertEqual(viewModel.filteredSections.flatMap(\.items).map(\.name), ["Bench Press"])

        viewModel.searchText = "quads"
        XCTAssertEqual(viewModel.filteredSections.flatMap(\.items).map(\.name), ["Squat"])
    }

    private var items: [ExerciseLibraryItem] {
        [
            ExerciseLibraryItem(id: 1, name: "Bench Press", type: .repBased, equipmentID: 1, equipmentName: "Barbell"),
            ExerciseLibraryItem(id: 2, name: "Cable Row", type: .repBased, equipmentID: 2, equipmentName: "Cable"),
            ExerciseLibraryItem(id: 3, name: "Back Squat", type: .repBased, equipmentID: 1, equipmentName: "Barbell"),
            ExerciseLibraryItem(id: 4, name: "Dead Bug", type: .repBased, equipmentID: nil, equipmentName: "No equipment")
        ]
    }
}
