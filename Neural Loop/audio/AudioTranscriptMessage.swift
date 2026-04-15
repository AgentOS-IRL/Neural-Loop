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

struct AudioTranscriptMessage: Identifiable, Equatable {
    let id: UUID
    let role: AudioTranscriptMessageRole
    let content: String

    init(
        id: UUID = UUID(),
        role: AudioTranscriptMessageRole = .user,
        content: String
    ) {
        self.id = id
        self.role = role
        self.content = content
    }

    static func == (lhs: AudioTranscriptMessage, rhs: AudioTranscriptMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content
    }
}
