import Foundation

enum AudioTranscriptMessageRole: String, Equatable {
    case user
    case assistant
    case toolResult
    case status
    case error
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
