import Foundation

enum WorkoutCatalogMapper {
    static func makeLibraryItems(
        equipment: [Equipment],
        exercises: [Exercise]
    ) -> [ExerciseLibraryItem] {
        let equipmentNamesByID = Dictionary(
            uniqueKeysWithValues: equipment.compactMap { equipment -> (Int64, String)? in
                guard let id = equipment.id else { return nil }
                return (id, equipment.name)
            }
        )

        return exercises.compactMap { exercise in
            guard let id = exercise.id else {
                return nil
            }

            let equipmentName = exercise.equipment_id.flatMap { equipmentNamesByID[$0] } ?? "No equipment"
            return ExerciseLibraryItem(
                id: id,
                name: exercise.name,
                type: exercise.type,
                equipmentID: exercise.equipment_id,
                equipmentName: equipmentName
            )
        }
        .sorted { lhs, rhs in
            switch lhs.name.localizedCaseInsensitiveCompare(rhs.name) {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                return lhs.id < rhs.id
            @unknown default:
                return lhs.id < rhs.id
            }
        }
    }

    static func filteredRoutine(
        _ payload: WorkoutRoutineGenerationPayload,
        matching catalog: [ExerciseLibraryItem]
    ) -> WorkoutRoutineGenerationPayload {
        let index = CatalogIndex(items: catalog)

        return WorkoutRoutineGenerationPayload(
            routineName: payload.routineName,
            notes: payload.notes,
            exercises: payload.exercises.filter { index.matchingItem(for: $0) != nil }
        )
    }

    static func makeDrafts(
        from generatedRoutine: WorkoutRoutineGenerationPayload,
        availableExercises: [ExerciseLibraryItem]
    ) -> [WorkoutTemplateExerciseDraft] {
        let validatedRoutine = filteredRoutine(generatedRoutine, matching: availableExercises)
        let index = CatalogIndex(items: availableExercises)

        return validatedRoutine.exercises.enumerated().compactMap { offset, proposedExercise in
            guard let exercise = index.matchingItem(for: proposedExercise) else {
                return nil
            }

            return WorkoutTemplateExerciseDraft(
                exercise: exercise,
                orderIndex: offset + 1,
                targetSetsText: "1",
                targetRepsText: exercise.type == .repBased ? "" : "",
                durationText: ""
            )
        }
    }

    private struct CatalogIndex {
        private let itemsByKey: [WorkoutCatalogExerciseKey: ExerciseLibraryItem]

        init(items: [ExerciseLibraryItem]) {
            var mappedItems: [WorkoutCatalogExerciseKey: ExerciseLibraryItem] = [:]
            for item in items {
                let key = WorkoutCatalogExerciseKey(name: item.name, equipment: item.equipmentName)
                mappedItems[key] = mappedItems[key] ?? item
            }
            itemsByKey = mappedItems
        }

        func matchingItem(for proposedExercise: WorkoutRoutineGenerationExercise) -> ExerciseLibraryItem? {
            itemsByKey[WorkoutCatalogExerciseKey(name: proposedExercise.name, equipment: proposedExercise.equipment)]
        }
    }

    private struct WorkoutCatalogExerciseKey: Hashable {
        let name: String
        let equipment: String?

        init(name: String, equipment: String?) {
            self.name = Self.normalizedName(name)
            self.equipment = Self.normalizedEquipment(equipment)
        }

        private static func normalizedName(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        }

        private static func normalizedEquipment(_ value: String?) -> String? {
            guard let value else {
                return nil
            }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            if trimmed.localizedCaseInsensitiveCompare("No equipment") == .orderedSame {
                return nil
            }

            return trimmed.localizedLowercase
        }
    }
}
