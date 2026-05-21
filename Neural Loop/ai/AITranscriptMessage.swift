import Foundation

enum AITranscriptMessageRole: String, Equatable {
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

enum AIToolResultKind: Equatable {
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

struct AITranscriptMessage: Identifiable, Equatable {
    let id: UUID
    let role: AITranscriptMessageRole
    var content: String
    let rawContent: String?
    let toolResultKind: AIToolResultKind?

    init(
        id: UUID = UUID(),
        role: AITranscriptMessageRole = .user,
        content: String,
        rawContent: String? = nil,
        toolResultKind: AIToolResultKind? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.rawContent = rawContent
        self.toolResultKind = toolResultKind
    }

    static func == (lhs: AITranscriptMessage, rhs: AITranscriptMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.rawContent == rhs.rawContent &&
        lhs.toolResultKind == rhs.toolResultKind
    }
}

