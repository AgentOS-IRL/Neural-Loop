import XCTest
@testable import Neural_Loop

final class WorkoutCatalogMapperTests: XCTestCase {
    func testMakeLibraryItemsIncludesMuscles() {
        let equipment = [Equipment(id: 1, name: "Barbell")]
        let exercises = [
            ExerciseWithMuscles(
                id: 10,
                name: "Bench Press",
                type: .repBased,
                equipment_id: 1,
                notes: nil,
                exercise_muscles: [
                    MuscleJoinResult(is_primary: true, muscle: Muscle(id: 1, name: "Chest")),
                    MuscleJoinResult(is_primary: false, muscle: Muscle(id: 2, name: "Triceps"))
                ]
            )
        ]

        let items = WorkoutCatalogMapper.makeLibraryItems(equipment: equipment, exercises: exercises)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].muscles.count, 2)
        XCTAssertEqual(items[0].muscles[0].muscleName, "Chest")
        XCTAssertTrue(items[0].muscles[0].isPrimary)
        XCTAssertEqual(items[0].muscles[1].muscleName, "Triceps")
        XCTAssertFalse(items[0].muscles[1].isPrimary)
    }

    func testMuscleChipSorting() {
        let equipment = [Equipment(id: 1, name: "Barbell")]
        let exercises = [
            ExerciseWithMuscles(
                id: 10,
                name: "Bench Press",
                type: .repBased,
                equipment_id: 1,
                notes: nil,
                exercise_muscles: [
                    MuscleJoinResult(is_primary: false, muscle: Muscle(id: 2, name: "Triceps")),
                    MuscleJoinResult(is_primary: true, muscle: Muscle(id: 1, name: "Chest")),
                    MuscleJoinResult(is_primary: false, muscle: Muscle(id: 3, name: "Shoulders"))
                ]
            )
        ]

        let items = WorkoutCatalogMapper.makeLibraryItems(equipment: equipment, exercises: exercises)

        XCTAssertEqual(items[0].muscles.count, 3)
        XCTAssertEqual(items[0].muscles[0].muscleName, "Chest", "Primary muscle should be first")
        XCTAssertTrue(items[0].muscles[0].isPrimary)
        
        // Secondary muscles should be sorted alphabetically
        XCTAssertEqual(items[0].muscles[1].muscleName, "Shoulders")
        XCTAssertEqual(items[0].muscles[2].muscleName, "Triceps")
    }
}
