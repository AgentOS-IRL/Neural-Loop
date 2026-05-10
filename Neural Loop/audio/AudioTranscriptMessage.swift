import Foundation

enum AudioTranscriptMessageRole: String, Equatable {
    case user
    case assistant
    case toolResult
    case status
    case error

    var displayTitle: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "Codex"
        case .toolResult:
            return "Tool result"
        case .status:
            return "Status"
        case .error:
            return "Issue"
        }
    }

    var systemImage: String {
        switch self {
        case .user:
            return "person.fill"
        case .assistant:
            return "sparkles"
        case .toolResult:
            return "checkmark.seal.fill"
        case .status:
            return "hourglass"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var alignsTrailing: Bool {
        self == .user
    }
}

enum AudioToolResultKind: Equatable {
    case personalNoteCreated
    case workNoteCreated
    case taskCreated

    var badgeText: String? {
        switch self {
        case .personalNoteCreated:
            return "Personal"
        case .workNoteCreated:
            return "Work"
        case .taskCreated:
            return nil
        }
    }

    var systemImage: String {
        switch self {
        case .personalNoteCreated:
            return "note.text"
        case .workNoteCreated:
            return "briefcase.fill"
        case .taskCreated:
            return "checkmark.seal.fill"
        }
    }
}

struct AudioTranscriptMessage: Identifiable, Equatable {
    let id: UUID
    let role: AudioTranscriptMessageRole
    let content: String
    let toolResultKind: AudioToolResultKind?

    init(
        id: UUID = UUID(),
        role: AudioTranscriptMessageRole = .user,
        content: String,
        toolResultKind: AudioToolResultKind? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolResultKind = toolResultKind
    }

    static func == (lhs: AudioTranscriptMessage, rhs: AudioTranscriptMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.toolResultKind == rhs.toolResultKind
    }
}
