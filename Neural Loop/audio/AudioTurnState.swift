import Foundation

enum AudioTurnState: Equatable {
    case idle
    case listening
    case processing
    case speaking(AudioTranscriptMessage.ID)
    case interrupting(AudioTranscriptMessage.ID)
    case suspended
}

enum AudioSpeechEndReason: Equatable {
    case finished
    case interrupted
    case canceled
    case failed
}

enum AudioSpeechStopReason: Equatable {
    case interrupted
    case muted
    case reset
}

struct AudioSpeechRequest: Equatable, Identifiable {
    let id: UUID
    let messageID: AudioTranscriptMessage.ID
    let text: String

    init(
        id: UUID = UUID(),
        messageID: AudioTranscriptMessage.ID,
        text: String
    ) {
        self.id = id
        self.messageID = messageID
        self.text = text
    }
}

enum AudioSpeechEvent: Equatable {
    case started(AudioSpeechRequest)
    case ended(AudioSpeechRequest, AudioSpeechEndReason)

    var request: AudioSpeechRequest {
        switch self {
        case .started(let request), .ended(let request, _):
            return request
        }
    }
}

struct AudioSpokenMessageRecord: Equatable {
    let messageID: AudioTranscriptMessage.ID
    var requestID: AudioSpeechRequest.ID?
    var endReason: AudioSpeechEndReason?
    var didStart: Bool

    init(
        messageID: AudioTranscriptMessage.ID,
        requestID: AudioSpeechRequest.ID? = nil,
        endReason: AudioSpeechEndReason? = nil,
        didStart: Bool = false
    ) {
        self.messageID = messageID
        self.requestID = requestID
        self.endReason = endReason
        self.didStart = didStart
    }
}
