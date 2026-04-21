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
    case muted
    case skipped
    case canceled
    case failed
    case teardown
}

enum AudioSpeechStopReason: Equatable {
    case interrupted
    case muted
    case reset
    case skipped
    case teardown
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

    var isTerminal: Bool {
        endReason != nil
    }
}

enum AudioTranscriptMessagePlaybackState: Equatable {
    case idle
    case speaking
    case finished
    case interrupted
    case muted
    case skipped
    case canceled
    case failed

    var isTerminal: Bool {
        switch self {
        case .idle, .speaking:
            return false
        case .finished, .interrupted, .muted, .skipped, .canceled, .failed:
            return true
        }
    }

    var shortLabel: String? {
        switch self {
        case .idle:
            return nil
        case .speaking:
            return "Speaking"
        case .finished:
            return "Done"
        case .interrupted:
            return "Interrupted"
        case .muted:
            return "Muted"
        case .skipped:
            return "Skipped"
        case .canceled:
            return "Stopped"
        case .failed:
            return "Failed"
        }
    }

    var systemImage: String? {
        switch self {
        case .idle:
            return nil
        case .speaking:
            return "speaker.wave.2.fill"
        case .finished:
            return "checkmark.circle.fill"
        case .interrupted:
            return "waveform.slash"
        case .muted:
            return "speaker.slash.fill"
        case .skipped:
            return "forward.end"
        case .canceled:
            return "stop.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
}
