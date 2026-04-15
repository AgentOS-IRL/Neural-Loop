import Foundation

enum AudioTranscriptMessageRole: String, Equatable {
    case user
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
}
