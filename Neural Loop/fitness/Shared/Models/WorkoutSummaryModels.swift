import Foundation

struct WorkoutTemplateSummary: Identifiable, Equatable, Codable {
    let id: Int64
    var title: String
    var exerciseCount: Int
    var setCount: Int

    var countText: String {
        let exerciseLabel = exerciseCount == 1 ? "exercise" : "exercises"
        let setLabel = setCount == 1 ? "set" : "sets"
        return "\(exerciseCount) \(exerciseLabel), \(setCount) \(setLabel)"
    }
}

struct WorkoutTemplateExerciseRow: Identifiable, Equatable {
    let id: Int64
    var exerciseName: String
    var equipmentName: String
    var setCount: Int
    var orderIndex: Int

    var setText: String {
        setCount == 1 ? "1 set" : "\(setCount) sets"
    }
}

struct WorkoutTemplateExerciseDraft: Identifiable, Equatable {
    let id: UUID
    var routineExerciseID: Int64?
    var exercise: ExerciseLibraryItem
    var orderIndex: Int
    var workingSetsText: String
    var warmupSetsText: String
    var targetRepsMinText: String
    var targetRepsMaxText: String
    var loadIncrementKgText: String
    var durationText: String
    var restSecondsText: String
    var supersetGroupID: Int?

    var supersetLabel: String? {
        supersetGroupID?.supersetLabel
    }

    init(
        id: UUID = UUID(),
        routineExerciseID: Int64? = nil,
        exercise: ExerciseLibraryItem,
        orderIndex: Int,
        workingSetsText: String,
        warmupSetsText: String,
        targetRepsMinText: String,
        targetRepsMaxText: String,
        loadIncrementKgText: String,
        durationText: String,
        restSecondsText: String,
        supersetGroupID: Int? = nil
    ) {
        self.id = id
        self.routineExerciseID = routineExerciseID
        self.exercise = exercise
        self.orderIndex = orderIndex
        self.workingSetsText = workingSetsText
        self.warmupSetsText = warmupSetsText
        self.targetRepsMinText = targetRepsMinText
        self.targetRepsMaxText = targetRepsMaxText
        self.loadIncrementKgText = loadIncrementKgText
        self.durationText = durationText
        self.restSecondsText = restSecondsText
        self.supersetGroupID = supersetGroupID
    }
}

extension Int {
    var supersetLabel: String? {
        guard self > 0 else { return nil }
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let index = (self - 1) % letters.count
        let letter = letters[letters.index(letters.startIndex, offsetBy: index)]
        return "Superset \(letter)"
    }
}

struct WorkoutSessionSummary: Identifiable, Equatable {
    let id: Int64
    let date: Date
    let title: String
    let notes: String?
    let startTime: String?
    let endTime: String?

    init(
        id: Int64,
        date: Date,
        title: String,
        notes: String?,
        startTime: String? = nil,
        endTime: String? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.notes = notes
        self.startTime = startTime
        self.endTime = endTime
    }

    var durationMinutes: Int? {
        guard let startSeconds = Self.seconds(from: startTime),
              let endSeconds = Self.seconds(from: endTime) else {
            return nil
        }

        let secondsInDay = 24 * 60 * 60
        let elapsedSeconds = endSeconds >= startSeconds
            ? endSeconds - startSeconds
            : (secondsInDay - startSeconds) + endSeconds

        return Int((Double(elapsedSeconds) / 60).rounded())
    }

    private static func seconds(from time: String?) -> Int? {
        guard let time, !time.isEmpty else { return nil }
        let parts = time.split(separator: ":").compactMap { Int(String($0)) }
        guard parts.count >= 2 else { return nil }

        let hours = parts[0]
        let minutes = parts[1]
        let seconds = parts.count >= 3 ? parts[2] : 0

        return (hours * 60 * 60) + (minutes * 60) + seconds
    }
}

struct WorkoutDraftSummary: Identifiable, Equatable {
    let id: Int64
    let routineID: Int64
    let sessionPointerID: String
    let title: String
    let sessionDate: Date
    let startTime: String?
    let notes: String?
    let exerciseCount: Int
    let setCount: Int
    let completedSetCount: Int
    let updatedAt: Date

    var progressText: String {
        "\(completedSetCount)/\(setCount) sets complete"
    }

    var metadataText: String {
        let exerciseLabel = exerciseCount == 1 ? "exercise" : "exercises"
        let setLabel = setCount == 1 ? "set" : "sets"
        return "\(exerciseCount) \(exerciseLabel) • \(setCount) \(setLabel)"
    }

    var subtitleText: String {
        if let startTime, !startTime.isEmpty {
            return "Started \(sessionDate.formatted(date: .abbreviated, time: .omitted)) at \(startTime)"
        }

        return "Started \(sessionDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct FitnessAnalysisSummaryResponse: Codable, Equatable {
    struct DailyVolume: Codable, Equatable {
        let date: String
        let volume: Double
    }
    struct ExerciseVolume: Codable, Equatable {
        let exercise_id: Int64
        let equipment_id: Int64?
        let volume: Double
        let primary_muscles: [String]
    }
    
    let daily_volumes: [DailyVolume]
    let exercise_volumes: [ExerciseVolume]
}

struct FitnessHomeBundle: Codable, Equatable {
    let routines: [WorkoutTemplateSummary]
    let sessions: [WorkoutSession]
    let analysis: FitnessAnalysisSummaryResponse
}

extension ActiveWorkoutDraft {
    var summary: WorkoutDraftSummary {
        let totalSets = exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.count
        }
        let completedSets = exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.filter(\.isCompleted).count
        }

        return WorkoutDraftSummary(
            id: routineID,
            routineID: routineID,
            sessionPointerID: watchSessionPointer.id,
            title: session.session_type,
            sessionDate: session.date,
            startTime: session.start_time,
            notes: session.notes,
            exerciseCount: exercises.count,
            setCount: totalSets,
            completedSetCount: completedSets,
            updatedAt: updatedAt
        )
    }
}


