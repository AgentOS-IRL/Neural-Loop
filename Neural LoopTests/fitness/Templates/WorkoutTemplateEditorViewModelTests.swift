import XCTest
@testable import Neural_Loop

@MainActor
final class WorkoutTemplateEditorViewModelTests: XCTestCase {
    func testCreateTemplateCreatesRoutineAndRoutineExercises() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [
                exercise(id: 10, name: "Bench Press", equipmentID: 1),
                exercise(id: 20, name: "Cable Row", equipmentID: 1)
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(mode: .create, dataManager: dataManager)

        await viewModel.loadIfNeeded()
        viewModel.title = "Push Day"
        viewModel.notes = "Main upper day"
        viewModel.syncExercises(with: [
            libraryItem(id: 10, name: "Bench Press"),
            libraryItem(id: 20, name: "Cable Row")
        ])
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[0].id, value: "3")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[0].id, value: "8")
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[1].id, value: "4")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[1].id, value: "10")

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(dataManager.createdRoutineRequests, [
            CreateRoutineRequest(name: "Push Day", notes: "Main upper day")
        ])
        XCTAssertEqual(dataManager.createdRoutineExercises.count, 2)
        XCTAssertEqual(dataManager.createdRoutineExercises.map(\.routine_id), [100, 100])
        XCTAssertEqual(dataManager.createdRoutineExercises.map(\.exercise_id), [10, 20])
        XCTAssertEqual(dataManager.createdRoutineExercises.map(\.order_index), [1, 2])
        XCTAssertEqual(dataManager.createdRoutineExercises.map(\.target_sets), [3, 4])
        XCTAssertEqual(dataManager.createdRoutineExercises.map(\.target_reps), [8, 10])
        XCTAssertTrue(dataManager.deletedRoutineIDs.isEmpty)
    }

    func testCreateTemplateSavesRestSeconds() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [exercise(id: 10, name: "Bench Press", equipmentID: 1)]
        )
        let viewModel = WorkoutTemplateEditorViewModel(mode: .create, dataManager: dataManager)

        await viewModel.loadIfNeeded()
        viewModel.title = "Push Day"
        viewModel.syncExercises(with: [libraryItem(id: 10, name: "Bench Press")])
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[0].id, value: "3")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[0].id, value: "8")
        viewModel.updateRestSeconds(id: viewModel.exerciseDrafts[0].id, value: "90")

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(dataManager.createdRoutineExercises.count, 1)
        XCTAssertEqual(dataManager.createdRoutineExercises[0].rest_seconds, 90)
    }

    func testEditTemplateLoadsRestSeconds() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [exercise(id: 10, name: "Bench Press", equipmentID: 1)],
            routinesByID: [
                500: Routine(id: 500, name: "Push Day", notes: nil)
            ],
            routineExercisesByRoutineID: [
                500: [
                    routineExercise(id: 1, routineID: 500, exerciseID: 10, orderIndex: 1, targetSets: 3, targetReps: 10, restSeconds: 45)
                ]
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 500, title: "Push Day", exerciseCount: 1, setCount: 3)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.exerciseDrafts.count, 1)
        XCTAssertEqual(viewModel.exerciseDrafts[0].restSecondsText, "45")
    }

    func testCreateTemplateRollsBackRoutineWhenExerciseInsertFails() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [exercise(id: 10, name: "Bench Press", equipmentID: 1)]
        )
        dataManager.shouldFailAddingRoutineExercise = true

        let viewModel = WorkoutTemplateEditorViewModel(mode: .create, dataManager: dataManager)
        await viewModel.loadIfNeeded()
        viewModel.title = "Push Day"
        viewModel.syncExercises(with: [libraryItem(id: 10, name: "Bench Press")])
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[0].id, value: "3")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[0].id, value: "8")

        let didSave = await viewModel.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(dataManager.createdRoutineRequests.count, 1)
        XCTAssertEqual(dataManager.deletedRoutineIDs, [100])
        XCTAssertEqual(dataManager.createdRoutineExercises.count, 0)
    }

    func testEditTemplateLoadsRoutineMetadataAndExercises() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Cable")],
            exercises: [
                exercise(id: 10, name: "Cable Row", equipmentID: 1),
                exercise(id: 20, name: "Face Pull", equipmentID: 1)
            ],
            routinesByID: [
                500: Routine(id: 500, name: "Back Day", notes: "Pull focused")
            ],
            routineExercisesByRoutineID: [
                500: [
                    routineExercise(id: 1, routineID: 500, exerciseID: 20, orderIndex: 2, targetSets: 4, targetReps: 12),
                    routineExercise(id: 2, routineID: 500, exerciseID: 10, orderIndex: 1, targetSets: nil, targetReps: 8)
                ]
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 500, title: "Back Day", exerciseCount: 2, setCount: 5)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.title, "Back Day")
        XCTAssertEqual(viewModel.notes, "Pull focused")
        XCTAssertEqual(viewModel.subtitleText, "2 exercises, 5 sets")
        XCTAssertEqual(viewModel.exerciseDrafts.map(\.exercise.id), [10, 20])
        XCTAssertEqual(viewModel.exerciseDrafts[0].targetSetsText, "1")
        XCTAssertEqual(viewModel.exerciseDrafts[0].targetRepsText, "8")
        XCTAssertEqual(viewModel.exerciseDrafts[1].targetSetsText, "4")
        XCTAssertEqual(viewModel.exerciseDrafts[1].targetRepsText, "12")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testEditTemplateUpdatesRoutineAndReconcilesExerciseRows() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Cable")],
            exercises: [
                exercise(id: 10, name: "Cable Row", equipmentID: 1),
                exercise(id: 20, name: "Face Pull", equipmentID: 1),
                exercise(id: 30, name: "Lat Pulldown", equipmentID: 1)
            ],
            routinesByID: [
                600: Routine(id: 600, name: "Back Day", notes: "Old notes")
            ],
            routineExercisesByRoutineID: [
                600: [
                    routineExercise(id: 1, routineID: 600, exerciseID: 10, orderIndex: 1, targetSets: 3, targetReps: 10),
                    routineExercise(id: 2, routineID: 600, exerciseID: 20, orderIndex: 2, targetSets: 2, targetReps: 15)
                ]
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 600, title: "Back Day", exerciseCount: 2, setCount: 5)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()
        viewModel.title = "Updated Back Day"
        viewModel.notes = "New notes"
        viewModel.syncExercises(with: [
            libraryItem(id: 10, name: "Cable Row"),
            libraryItem(id: 30, name: "Lat Pulldown")
        ])
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[0].id, value: "5")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[0].id, value: "12")
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[1].id, value: "4")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[1].id, value: "10")

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(dataManager.updatedRoutineRequests.last?.name, "Updated Back Day")
        XCTAssertEqual(dataManager.updatedRoutineRequests.last?.notes, "New notes")
        XCTAssertEqual(dataManager.deletedRoutineExerciseIDs, [2])
        XCTAssertEqual(dataManager.createdRoutineExercises.map(\.exercise_id), [30])

        let remainingRows = dataManager.routineExercisesByRoutineID[600] ?? []
        XCTAssertEqual(remainingRows.count, 2)
        XCTAssertEqual(remainingRows.sorted { $0.order_index < $1.order_index }.map(\.exercise_id), [10, 30])
        XCTAssertEqual(remainingRows.sorted { $0.order_index < $1.order_index }.map(\.target_sets), [5, 4])
        XCTAssertEqual(remainingRows.sorted { $0.order_index < $1.order_index }.map(\.target_reps), [12, 10])
    }

    func testEditTemplateRollsBackRoutineExerciseStateWhenFinalUpdateFails() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Cable")],
            exercises: [
                exercise(id: 10, name: "Cable Row", equipmentID: 1),
                exercise(id: 20, name: "Face Pull", equipmentID: 1),
                exercise(id: 30, name: "Lat Pulldown", equipmentID: 1)
            ],
            routinesByID: [
                800: Routine(id: 800, name: "Back Day", notes: "Old notes")
            ],
            routineExercisesByRoutineID: [
                800: [
                    routineExercise(id: 1, routineID: 800, exerciseID: 10, orderIndex: 1, targetSets: 3, targetReps: 10),
                    routineExercise(id: 2, routineID: 800, exerciseID: 20, orderIndex: 2, targetSets: 2, targetReps: 15)
                ]
            ]
        )
        dataManager.failOnUpdateRoutineExerciseCall = 2

        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 800, title: "Back Day", exerciseCount: 2, setCount: 5)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()
        viewModel.title = "Updated Back Day"
        viewModel.syncExercises(with: [
            libraryItem(id: 10, name: "Cable Row"),
            libraryItem(id: 30, name: "Lat Pulldown")
        ])
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[0].id, value: "5")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[0].id, value: "12")
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[1].id, value: "4")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[1].id, value: "10")

        let didSave = await viewModel.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.errorMessage, "Unable to save routine exercise.")

        let restoredRows = dataManager.routineExercisesByRoutineID[800] ?? []
        XCTAssertEqual(restoredRows.count, 2)
        XCTAssertEqual(restoredRows.sorted { $0.order_index < $1.order_index }.map(\.exercise_id), [10, 20])
        XCTAssertEqual(restoredRows.sorted { $0.order_index < $1.order_index }.map(\.target_sets), [3, 2])
        XCTAssertEqual(restoredRows.sorted { $0.order_index < $1.order_index }.map(\.target_reps), [10, 15])
        XCTAssertTrue(restoredRows.allSatisfy { $0.order_index == 1 || $0.order_index == 2 })
        XCTAssertFalse(restoredRows.contains { $0.exercise_id == 30 })
        XCTAssertEqual(dataManager.deletedRoutineExerciseIDs, [2, 1000])
    }

    func testCanSaveRequiresNameAndExercises() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [exercise(id: 10, name: "Bench Press", equipmentID: 1)]
        )
        let viewModel = WorkoutTemplateEditorViewModel(mode: .create, dataManager: dataManager)

        await viewModel.loadIfNeeded()
        XCTAssertFalse(viewModel.canSave)

        viewModel.title = "Push Day"
        XCTAssertFalse(viewModel.canSave)

        viewModel.syncExercises(with: [libraryItem(id: 10, name: "Bench Press")])
        XCTAssertFalse(viewModel.canSave)

        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[0].id, value: "3")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[0].id, value: "8")
        XCTAssertTrue(viewModel.canSave)
    }

    func testValidationErrorForInvalidRestSeconds() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [exercise(id: 10, name: "Bench Press", equipmentID: 1)]
        )
        let viewModel = WorkoutTemplateEditorViewModel(mode: .create, dataManager: dataManager)

        await viewModel.loadIfNeeded()
        viewModel.title = "Push Day"
        viewModel.syncExercises(with: [libraryItem(id: 10, name: "Bench Press")])
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[0].id, value: "3")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[0].id, value: "8")
        
        viewModel.updateRestSeconds(id: viewModel.exerciseDrafts[0].id, value: "abc")
        XCTAssertFalse(viewModel.canSave)
        
        viewModel.updateRestSeconds(id: viewModel.exerciseDrafts[0].id, value: "-10")
        XCTAssertFalse(viewModel.canSave)
        
        viewModel.updateRestSeconds(id: viewModel.exerciseDrafts[0].id, value: "60")
        XCTAssertTrue(viewModel.canSave)
    }

    func testTargetSetFallbackUsesOneForMissingTargetSets() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Bodyweight")],
            exercises: [exercise(id: 10, name: "Push Up", equipmentID: 1)],
            routinesByID: [
                700: Routine(id: 700, name: "Upper Body", notes: nil)
            ],
            routineExercisesByRoutineID: [
                700: [
                    routineExercise(id: 1, routineID: 700, exerciseID: 10, orderIndex: 1, targetSets: nil, targetReps: 12)
                ]
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 700, title: "Upper Body", exerciseCount: 1, setCount: 1)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()
        viewModel.title = "Upper Body"
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[0].id, value: "12")

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(viewModel.exerciseDrafts.first?.targetSetsText, "1")
        XCTAssertEqual(dataManager.routineExercisesByRoutineID[700]?.first?.target_sets, 1)
    }

    func testSaveSurfacesReadableErrorMessage() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [exercise(id: 10, name: "Bench Press", equipmentID: 1)]
        )
        dataManager.shouldFailAddingRoutineExercise = true

        let viewModel = WorkoutTemplateEditorViewModel(mode: .create, dataManager: dataManager)
        await viewModel.loadIfNeeded()
        viewModel.title = "Push Day"
        viewModel.syncExercises(with: [libraryItem(id: 10, name: "Bench Press")])
        viewModel.updateTargetSets(id: viewModel.exerciseDrafts[0].id, value: "3")
        viewModel.updateTargetReps(id: viewModel.exerciseDrafts[0].id, value: "8")

        let didSave = await viewModel.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.errorMessage, "Unable to save routine exercise.")
        XCTAssertTrue(viewModel.canSave)
    }

    func testWorkoutCatalogFilteringKeepsValidExercisesAndDropsInvalidEntries() {
        let catalog = WorkoutCatalogMapper.makeLibraryItems(
            equipment: [
                equipment(id: 1, name: "Barbell"),
                equipment(id: 2, name: "Cable")
            ],
            exercises: [
                exercise(id: 10, name: "Bench Press", equipmentID: 1),
                exercise(id: 20, name: "Cable Row", equipmentID: 2),
                exercise(id: 30, name: "Deadlift", equipmentID: 1)
            ]
        )
        let payload = WorkoutRoutineGenerationPayload(
            routineName: "Push Day",
            notes: "Upper body focus",
            exercises: [
                WorkoutRoutineGenerationExercise(name: "Bench Press", equipment: "Barbell"),
                WorkoutRoutineGenerationExercise(name: "Bench Press", equipment: "Dumbbell"),
                WorkoutRoutineGenerationExercise(name: "Not Real", equipment: "Barbell"),
                WorkoutRoutineGenerationExercise(name: "   ", equipment: "   "),
                WorkoutRoutineGenerationExercise(name: "Cable Row", equipment: "Cable")
            ]
        )

        let filtered = WorkoutCatalogMapper.filteredRoutine(payload, matching: catalog)

        XCTAssertEqual(filtered.routineName, "Push Day")
        XCTAssertEqual(filtered.notes, "Upper body focus")
        XCTAssertEqual(filtered.exercises.map(\.name), ["Bench Press", "Cable Row"])
        XCTAssertEqual(filtered.exercises.map(\.equipment), ["Barbell", "Cable"])
    }

    func testGeneratedRoutineSeedsEditorWithFilteredExercisesOnly() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [
                equipment(id: 1, name: "Barbell"),
                equipment(id: 2, name: "Cable")
            ],
            exercises: [
                exercise(id: 10, name: "Bench Press", equipmentID: 1),
                exercise(id: 20, name: "Cable Row", equipmentID: 2)
            ]
        )
        let generatedRoutine = WorkoutRoutineGenerationPayload(
            routineName: "Push Day",
            notes: "Upper body focus",
            exercises: [
                WorkoutRoutineGenerationExercise(name: "Bench Press", equipment: "Barbell"),
                WorkoutRoutineGenerationExercise(name: "Bench Press", equipment: "Dumbbell"),
                WorkoutRoutineGenerationExercise(name: "Cable Row", equipment: "Cable")
            ]
        )

        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .create,
            dataManager: dataManager,
            generatedRoutine: generatedRoutine
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.title, "Push Day")
        XCTAssertEqual(viewModel.notes, "Upper body focus")
        XCTAssertEqual(viewModel.exerciseDrafts.map(\.exercise.id), [10, 20])
        XCTAssertEqual(viewModel.exerciseDrafts.map(\.orderIndex), [1, 2])
        XCTAssertEqual(viewModel.exerciseDrafts.map(\.targetSetsText), ["1", "1"])
        XCTAssertEqual(viewModel.exerciseDrafts.map(\.exercise.name), ["Bench Press", "Cable Row"])
    }

    func testLoadRoutineWithSupersets() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [
                exercise(id: 10, name: "Ex 10", equipmentID: 1),
                exercise(id: 20, name: "Ex 20", equipmentID: 1)
            ],
            routinesByID: [
                1: Routine(id: 1, name: "Routine", notes: nil)
            ],
            routineExercisesByRoutineID: [
                1: [
                    routineExercise(id: 100, routineID: 1, exerciseID: 10, orderIndex: 1, targetSets: 3, targetReps: 10, supersetGroupID: 1),
                    routineExercise(id: 101, routineID: 1, exerciseID: 20, orderIndex: 2, targetSets: 3, targetReps: 10, supersetGroupID: 1)
                ]
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 1, title: "Routine", exerciseCount: 2, setCount: 6)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.exerciseDrafts.count, 2)
        XCTAssertEqual(viewModel.exerciseDrafts[0].supersetGroupID, 1)
        XCTAssertEqual(viewModel.exerciseDrafts[1].supersetGroupID, 1)
        XCTAssertEqual(viewModel.exerciseDrafts[0].supersetLabel, "Superset A")
    }

    func testSaveRoutineWithSupersets() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [
                exercise(id: 10, name: "Ex 10", equipmentID: 1),
                exercise(id: 20, name: "Ex 20", equipmentID: 1)
            ],
            routinesByID: [
                1: Routine(id: 1, name: "Routine", notes: nil)
            ],
            routineExercisesByRoutineID: [
                1: [
                    routineExercise(id: 100, routineID: 1, exerciseID: 10, orderIndex: 1, targetSets: 3, targetReps: 10, supersetGroupID: 2),
                    routineExercise(id: 101, routineID: 1, exerciseID: 20, orderIndex: 2, targetSets: 3, targetReps: 10, supersetGroupID: 2)
                ]
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 1, title: "Routine", exerciseCount: 2, setCount: 6)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()
        viewModel.syncExercises(with: [
            libraryItem(id: 10, name: "Ex 10"),
            libraryItem(id: 20, name: "Ex 20")
        ])

        // Update reps/sets for Ex 20 to pass validation
        if let ex20Draft = viewModel.exerciseDrafts.first(where: { $0.exercise.id == 20 }) {
            viewModel.updateTargetSets(id: ex20Draft.id, value: "3")
            viewModel.updateTargetReps(id: ex20Draft.id, value: "10")
        }

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        let savedRows = dataManager.routineExercisesByRoutineID[1] ?? []
        XCTAssertEqual(savedRows.first(where: { $0.exercise_id == 10 })?.superset_group_id, 2)
        XCTAssertEqual(savedRows.first(where: { $0.exercise_id == 20 })?.superset_group_id, 2)
    }
    func testReorderExercisesPreservesSupersets() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [
                exercise(id: 10, name: "Ex 10", equipmentID: 1),
                exercise(id: 20, name: "Ex 20", equipmentID: 1)
            ],
            routinesByID: [
                1: Routine(id: 1, name: "Routine", notes: nil)
            ],
            routineExercisesByRoutineID: [
                1: [
                    routineExercise(id: 100, routineID: 1, exerciseID: 10, orderIndex: 1, targetSets: 3, targetReps: 10, supersetGroupID: 1),
                    routineExercise(id: 101, routineID: 1, exerciseID: 20, orderIndex: 2, targetSets: 3, targetReps: 10, supersetGroupID: 1)
                ]
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 1, title: "Routine", exerciseCount: 2, setCount: 6)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.exerciseDrafts[0].exercise.id, 10)
        XCTAssertEqual(viewModel.exerciseDrafts[0].supersetGroupID, 1)
        XCTAssertEqual(viewModel.exerciseDrafts[1].supersetGroupID, 1)

        viewModel.moveExercise(id: viewModel.exerciseDrafts[0].id, by: 1)

        XCTAssertEqual(viewModel.exerciseDrafts[0].exercise.id, 20)
        XCTAssertEqual(viewModel.exerciseDrafts[0].supersetGroupID, 1)
        XCTAssertEqual(viewModel.exerciseDrafts[1].exercise.id, 10)
        XCTAssertEqual(viewModel.exerciseDrafts[1].supersetGroupID, 1)
    }

    func testRemovingExerciseFromSupersetClearsOrphanID() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [
                exercise(id: 10, name: "Ex 10", equipmentID: 1),
                exercise(id: 20, name: "Ex 20", equipmentID: 1)
            ],
            routinesByID: [
                1: Routine(id: 1, name: "Routine", notes: nil)
            ],
            routineExercisesByRoutineID: [
                1: [
                    routineExercise(id: 100, routineID: 1, exerciseID: 10, orderIndex: 1, targetSets: 3, targetReps: 10, supersetGroupID: 1),
                    routineExercise(id: 101, routineID: 1, exerciseID: 20, orderIndex: 2, targetSets: 3, targetReps: 10, supersetGroupID: 1)
                ]
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 1, title: "Routine", exerciseCount: 2, setCount: 6)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.exerciseDrafts[0].supersetGroupID, 1)
        XCTAssertEqual(viewModel.exerciseDrafts[1].supersetGroupID, 1)

        // Remove one exercise
        viewModel.removeExercise(id: viewModel.exerciseDrafts[0].id)

        // Remaining exercise should have nil supersetGroupID
        XCTAssertEqual(viewModel.exerciseDrafts.count, 1)
        XCTAssertNil(viewModel.exerciseDrafts[0].supersetGroupID)
    }

    func testSyncingExercisesNormalizesSupersets() async {
        let dataManager = FakeWorkoutTemplateEditorDataManager(
            equipment: [equipment(id: 1, name: "Barbell")],
            exercises: [
                exercise(id: 10, name: "Ex 10", equipmentID: 1),
                exercise(id: 20, name: "Ex 20", equipmentID: 1)
            ],
            routinesByID: [
                1: Routine(id: 1, name: "Routine", notes: nil)
            ],
            routineExercisesByRoutineID: [
                1: [
                    routineExercise(id: 100, routineID: 1, exerciseID: 10, orderIndex: 1, targetSets: 3, targetReps: 10, supersetGroupID: 1),
                    routineExercise(id: 101, routineID: 1, exerciseID: 20, orderIndex: 2, targetSets: 3, targetReps: 10, supersetGroupID: 1)
                ]
            ]
        )
        let viewModel = WorkoutTemplateEditorViewModel(
            mode: .edit(WorkoutTemplateSummary(id: 1, title: "Routine", exerciseCount: 2, setCount: 6)),
            dataManager: dataManager
        )

        await viewModel.loadIfNeeded()
        
        // Deselect one exercise from the library
        viewModel.syncExercises(with: [
            libraryItem(id: 10, name: "Ex 10")
        ])

        XCTAssertEqual(viewModel.exerciseDrafts.count, 1)
        XCTAssertNil(viewModel.exerciseDrafts[0].supersetGroupID)
    }

    private func equipment(id: Int64, name: String) -> Equipment {
        Equipment(id: id, name: name)
    }

    private func exercise(id: Int64, name: String, equipmentID: Int64?) -> ExerciseWithMuscles {
        ExerciseWithMuscles(
            id: id,
            name: name,
            type: .repBased,
            equipment_id: equipmentID,
            notes: nil,
            exercise_muscles: []
        )
    }

    private func libraryItem(id: Int64, name: String) -> ExerciseLibraryItem {
        ExerciseLibraryItem(id: id, name: name, type: .repBased, equipmentID: 1, equipmentName: "Barbell")
    }

    private func routineExercise(
        id: Int64,
        routineID: Int64,
        exerciseID: Int64,
        orderIndex: Int,
        targetSets: Int?,
        targetReps: Int?,
        restSeconds: Int? = nil,
        supersetGroupID: Int? = nil
    ) -> RoutineExercise {
        RoutineExercise(
            id: id,
            routine_id: routineID,
            exercise_id: exerciseID,
            order_index: orderIndex,
            target_sets: targetSets,
            target_reps: targetReps,
            rest_seconds: restSeconds,
            superset_group_id: supersetGroupID,
            duration: nil
        )
    }
}

private final class FakeWorkoutTemplateEditorDataManager: WorkoutTemplateEditingDataManaging {
    var equipment: [Equipment]
    var exercises: [ExerciseWithMuscles]
    var routinesByID: [Int64: Routine]
    var routineExercisesByRoutineID: [Int64: [RoutineExercise]]
    var createdRoutineRequests: [CreateRoutineRequest] = []
    var updatedRoutineRequests: [Routine] = []
    var deletedRoutineIDs: [Int64] = []
    var createdRoutineExercises: [CreateRoutineExerciseRequest] = []
    var updatedRoutineExercises: [RoutineExercise] = []
    var deletedRoutineExerciseIDs: [Int64] = []
    var shouldFailAddingRoutineExercise = false
    var failOnUpdateRoutineExerciseCall: Int?

    private var nextRoutineID: Int64 = 100
    private var nextRoutineExerciseID: Int64 = 1_000
    private var updateRoutineExerciseCallCount = 0

    init(
        equipment: [Equipment] = [],
        exercises: [ExerciseWithMuscles] = [],
        routinesByID: [Int64: Routine] = [:],
        routineExercisesByRoutineID: [Int64: [RoutineExercise]] = [:]
    ) {
        self.equipment = equipment
        self.exercises = exercises
        self.routinesByID = routinesByID
        self.routineExercisesByRoutineID = routineExercisesByRoutineID
    }

    func fetchAllEquipment() async throws -> [Equipment] {
        equipment
    }

    func fetchAllExercises() async throws -> [Exercise] {
        return []
    }

    func fetchAllExercisesWithMuscles() async throws -> [ExerciseWithMuscles] {
        return exercises
    }


    func fetchRoutine(by id: Int64) async throws -> Routine? {
        routinesByID[id]
    }

    func fetchAllRoutines() async throws -> [Routine] {
        routinesByID.values.sorted { lhs, rhs in
            (lhs.id ?? 0) < (rhs.id ?? 0)
        }
    }

    func fetchRoutineExercises(routineId: Int64) async throws -> [RoutineExercise] {
        (routineExercisesByRoutineID[routineId] ?? []).sorted { lhs, rhs in
            lhs.order_index < rhs.order_index
        }
    }

    func createRoutine(_ request: CreateRoutineRequest) async throws -> Routine {
        createdRoutineRequests.append(request)
        let routine = Routine(id: nextRoutineID, name: request.name, notes: request.notes)
        routinesByID[nextRoutineID] = routine
        nextRoutineID += 1
        return routine
    }

    func updateRoutine(_ routine: Routine) async throws -> Routine {
        updatedRoutineRequests.append(routine)
        guard let id = routine.id else {
            return routine
        }

        routinesByID[id] = routine
        return routine
    }

    func deleteRoutine(id: Int64) async throws {
        deletedRoutineIDs.append(id)
        routinesByID[id] = nil
        routineExercisesByRoutineID[id] = nil
    }

    func addRoutineExercise(_ request: CreateRoutineExerciseRequest) async throws -> RoutineExercise {
        if shouldFailAddingRoutineExercise {
            throw FakeWorkoutTemplateEditorError.unableToSaveRoutineExercise
        }

        createdRoutineExercises.append(request)
        let routineExercise = RoutineExercise(
            id: nextRoutineExerciseID,
            routine_id: request.routine_id,
            exercise_id: request.exercise_id,
            order_index: request.order_index,
            target_sets: request.target_sets,
            target_reps: request.target_reps,
            rest_seconds: request.rest_seconds,
            superset_group_id: request.superset_group_id,
            duration: request.duration
        )
        nextRoutineExerciseID += 1
        var rows = routineExercisesByRoutineID[request.routine_id] ?? []
        rows.append(routineExercise)
        routineExercisesByRoutineID[request.routine_id] = rows.sorted { lhs, rhs in
            lhs.order_index < rhs.order_index
        }
        return routineExercise
    }

    func updateRoutineExercise(_ routineExercise: RoutineExercise) async throws -> RoutineExercise {
        updateRoutineExerciseCallCount += 1
        if failOnUpdateRoutineExerciseCall == updateRoutineExerciseCallCount {
            throw FakeWorkoutTemplateEditorError.unableToSaveRoutineExercise
        }

        updatedRoutineExercises.append(routineExercise)
        guard let id = routineExercise.id else {
            return routineExercise
        }

        let routineID = routineExercise.routine_id
        var rows = routineExercisesByRoutineID[routineID] ?? []
        if let index = rows.firstIndex(where: { $0.id == id }) {
            rows[index] = routineExercise
        } else {
            rows.append(routineExercise)
        }
        routineExercisesByRoutineID[routineID] = rows.sorted { lhs, rhs in
            lhs.order_index < rhs.order_index
        }
        return routineExercise
    }

    func deleteRoutineExercise(id: Int64) async throws {
        deletedRoutineExerciseIDs.append(id)
        for routineID in routineExercisesByRoutineID.keys {
            routineExercisesByRoutineID[routineID]?.removeAll { $0.id == id }
        }
    }
}

private enum FakeWorkoutTemplateEditorError: LocalizedError {
    case unableToSaveRoutineExercise

    var errorDescription: String? {
        switch self {
        case .unableToSaveRoutineExercise:
            return "Unable to save routine exercise."
        }
    }
}
