import Foundation

public nonisolated struct WorkoutWatchSessionAction: Codable, Hashable {
    public var session: WorkoutSessionPointer
    
    public init(session: WorkoutSessionPointer) {
        self.session = session
    }
}

public nonisolated struct WorkoutWatchRestTimerAdjustmentAction: Codable, Hashable {
    public var session: WorkoutSessionPointer
    /// A signed number of seconds to add to the remaining rest time.
    public var signedSeconds: Int

    public init(session: WorkoutSessionPointer, signedSeconds: Int) {
        self.session = session
        self.signedSeconds = signedSeconds
    }
}

public nonisolated struct WorkoutWatchSetReference: Codable, Hashable {
    public var session: WorkoutSessionPointer
    public var exerciseID: String
    /// The numeric routine-exercise ID that the iPhone draft uses for lookups
    /// (i.e. WorkoutExerciseCardState.id / RoutineExercise.id).
    public var routineExerciseID: Int64?
    public var setID: String
    
    public init(session: WorkoutSessionPointer, exerciseID: String, routineExerciseID: Int64? = nil, setID: String) {
        self.session = session
        self.exerciseID = exerciseID
        self.routineExerciseID = routineExerciseID
        self.setID = setID
    }
}

public nonisolated struct WorkoutWatchExerciseReference: Codable, Hashable {
    public var session: WorkoutSessionPointer
    public var exerciseID: String
    /// The numeric routine-exercise ID that the iPhone draft uses for lookups
    /// (i.e. WorkoutExerciseCardState.id / RoutineExercise.id).
    public var routineExerciseID: Int64?
    
    public init(session: WorkoutSessionPointer, exerciseID: String, routineExerciseID: Int64? = nil) {
        self.session = session
        self.exerciseID = exerciseID
        self.routineExerciseID = routineExerciseID
    }
}

public nonisolated struct WorkoutWatchSetValuesAction: Codable, Hashable {
    public var reference: WorkoutWatchSetReference
    public var values: WorkoutSetValuesSnapshot
    
    public init(reference: WorkoutWatchSetReference, values: WorkoutSetValuesSnapshot) {
        self.reference = reference
        self.values = values
    }
}

public nonisolated struct WorkoutWatchSetCompletionAction: Codable, Hashable {
    public var reference: WorkoutWatchSetReference
    public var isCompleted: Bool
    
    public init(reference: WorkoutWatchSetReference, isCompleted: Bool) {
        self.reference = reference
        self.isCompleted = isCompleted
    }
}

public nonisolated struct WorkoutWatchExerciseCompletionAction: Codable, Hashable {
    public var reference: WorkoutWatchExerciseReference
    public var isCompleted: Bool
    
    public init(reference: WorkoutWatchExerciseReference, isCompleted: Bool) {
        self.reference = reference
        self.isCompleted = isCompleted
    }
}

public nonisolated enum WorkoutWatchActionPayload: Codable, Hashable {
    case requestSnapshot(WorkoutWatchSessionAction)
    case updateSetValues(WorkoutWatchSetValuesAction)
    case toggleSetCompletion(WorkoutWatchSetCompletionAction)
    case addSet(WorkoutWatchExerciseReference)
    case updateExerciseCompletion(WorkoutWatchExerciseCompletionAction)
    case finishWorkout(WorkoutWatchSessionAction)
    case cancelRestTimer(WorkoutWatchSessionAction)
    case adjustRestTimer(WorkoutWatchRestTimerAdjustmentAction)

    private enum ActionType: String {
        case requestSnapshot
        case updateSetValues
        case toggleSetCompletion
        case addSet
        case updateExerciseCompletion
        case finishWorkout
        case cancelRestTimer
        case adjustRestTimer
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case session
        case reference
        case values
        case isCompleted
        case signedSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)

        guard let type = ActionType(rawValue: typeString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown workout watch action type: \(typeString)"
            )
        }

        switch type {
        case .requestSnapshot:
            let session = try container.decode(WorkoutSessionPointer.self, forKey: .session)
            self = .requestSnapshot(WorkoutWatchSessionAction(session: session))
        case .updateSetValues:
            let reference = try container.decode(WorkoutWatchSetReference.self, forKey: .reference)
            let values = try container.decode(WorkoutSetValuesSnapshot.self, forKey: .values)
            self = .updateSetValues(WorkoutWatchSetValuesAction(reference: reference, values: values))
        case .toggleSetCompletion:
            let reference = try container.decode(WorkoutWatchSetReference.self, forKey: .reference)
            let isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
            self = .toggleSetCompletion(WorkoutWatchSetCompletionAction(reference: reference, isCompleted: isCompleted))
        case .addSet:
            let reference = try container.decode(WorkoutWatchExerciseReference.self, forKey: .reference)
            self = .addSet(reference)
        case .updateExerciseCompletion:
            let reference = try container.decode(WorkoutWatchExerciseReference.self, forKey: .reference)
            let isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
            self = .updateExerciseCompletion(WorkoutWatchExerciseCompletionAction(reference: reference, isCompleted: isCompleted))
        case .finishWorkout:
            let session = try container.decode(WorkoutSessionPointer.self, forKey: .session)
            self = .finishWorkout(WorkoutWatchSessionAction(session: session))
        case .cancelRestTimer:
            let session = try container.decode(WorkoutSessionPointer.self, forKey: .session)
            self = .cancelRestTimer(WorkoutWatchSessionAction(session: session))
        case .adjustRestTimer:
            let session = try container.decode(WorkoutSessionPointer.self, forKey: .session)
            let signedSeconds = try container.decode(Int.self, forKey: .signedSeconds)
            self = .adjustRestTimer(
                WorkoutWatchRestTimerAdjustmentAction(
                    session: session,
                    signedSeconds: signedSeconds
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .requestSnapshot(let action):
            try container.encode(ActionType.requestSnapshot.rawValue, forKey: .type)
            try container.encode(action.session, forKey: .session)
        case .updateSetValues(let action):
            try container.encode(ActionType.updateSetValues.rawValue, forKey: .type)
            try container.encode(action.reference, forKey: .reference)
            try container.encode(action.values, forKey: .values)
        case .toggleSetCompletion(let action):
            try container.encode(ActionType.toggleSetCompletion.rawValue, forKey: .type)
            try container.encode(action.reference, forKey: .reference)
            try container.encode(action.isCompleted, forKey: .isCompleted)
        case .addSet(let reference):
            try container.encode(ActionType.addSet.rawValue, forKey: .type)
            try container.encode(reference, forKey: .reference)
        case .updateExerciseCompletion(let action):
            try container.encode(ActionType.updateExerciseCompletion.rawValue, forKey: .type)
            try container.encode(action.reference, forKey: .reference)
            try container.encode(action.isCompleted, forKey: .isCompleted)
        case .finishWorkout(let action):
            try container.encode(ActionType.finishWorkout.rawValue, forKey: .type)
            try container.encode(action.session, forKey: .session)
        case .cancelRestTimer(let action):
            try container.encode(ActionType.cancelRestTimer.rawValue, forKey: .type)
            try container.encode(action.session, forKey: .session)
        case .adjustRestTimer(let action):
            try container.encode(ActionType.adjustRestTimer.rawValue, forKey: .type)
            try container.encode(action.session, forKey: .session)
            try container.encode(action.signedSeconds, forKey: .signedSeconds)
        }
    }
}

public extension WorkoutWatchActionPayload {
    var session: WorkoutSessionPointer {
        switch self {
        case .requestSnapshot(let action): return action.session
        case .updateSetValues(let action): return action.reference.session
        case .toggleSetCompletion(let action): return action.reference.session
        case .addSet(let reference): return reference.session
        case .updateExerciseCompletion(let action): return action.reference.session
        case .finishWorkout(let action): return action.session
        case .cancelRestTimer(let action): return action.session
        case .adjustRestTimer(let action): return action.session
        }
    }
}

// MARK: - Acknowledgement & Finalization Models

public struct WorkoutActionAck: Codable {
    public let actionID: UUID
    public let status: AckStatus
    
    public enum AckStatus: String, Codable {
        case applied
        case failed
        case notFound
    }
    
    public init(actionID: UUID, status: AckStatus) {
        self.actionID = actionID
        self.status = status
    }
}

public struct WorkoutFinalizedResult: Codable {
    public let sessionID: String
    public let success: Bool
    public let errorMessage: String?
    
    public init(sessionID: String, success: Bool, errorMessage: String? = nil) {
        self.sessionID = sessionID
        self.success = success
        self.errorMessage = errorMessage
    }
}

public enum WorkoutSyncPayload: Codable {
    case active(ActiveWorkoutSnapshot)
    case cleared(ClearedWorkoutSnapshot)
}

public struct ClearedWorkoutSnapshot: Codable {
    public let sessionID: String
    public let reason: ClearReason
    public let clearedAt: Date
    
    public init(sessionID: String, reason: ClearReason, clearedAt: Date = Date()) {
        self.sessionID = sessionID
        self.reason = reason
        self.clearedAt = clearedAt
    }
}

public enum ClearReason: String, Codable {
    case finalized
    case cancelledOnPhone
    case staleExpired
    case replacedByNewSession
}

