import Foundation

enum AudioModeBannerTone: Equatable {
    case info
    case warning
    case error
}

struct AudioModeTranscriptionViewData: Equatable {
    let displayState: AudioTranscriptionDisplayState
    let title: String
    let detail: String
    let badgeText: String?
    let transcriptTitle: String
    let transcriptIconName: String
    let transcriptBadgeText: String?
    let transcriptBody: String
    let microphoneSystemImage: String
    let micButtonLabel: String
    let isActionDisabled: Bool
    let isRecording: Bool
    let transcriptHistoryCount: Int
}

struct AudioModeConversationViewData: Equatable {
    let messages: [AudioTranscriptMessage]
    let bannerText: String?
    let bannerTone: AudioModeBannerTone?
    let isSending: Bool
    let isLLMDisabled: Bool
    let noteTargetStatusText: String?

    init(
        messages: [AudioTranscriptMessage],
        bannerText: String?,
        bannerTone: AudioModeBannerTone?,
        isSending: Bool,
        isLLMDisabled: Bool,
        noteTargetStatusText: String? = nil
    ) {
        self.messages = messages
        self.bannerText = bannerText
        self.bannerTone = bannerTone
        self.isSending = isSending
        self.isLLMDisabled = isLLMDisabled
        self.noteTargetStatusText = noteTargetStatusText
    }

    var scrollTargetMessageID: AudioTranscriptMessage.ID? {
        messages.last?.id
    }
}

struct AudioModeViewState: Equatable {
    struct Hero: Equatable {
        let title: String
        let detail: String
        let badgeText: String?
        let tintState: AudioTranscriptionDisplayState
        let microphoneSystemImage: String
        let micButtonLabel: String
        let isActionDisabled: Bool
        let isRecording: Bool
    }

    struct Transcript: Equatable {
        let title: String
        let iconName: String
        let badgeText: String?
        let body: String
        let footnote: String?
    }

    struct Conversation: Equatable {
        let messages: [AudioTranscriptMessage]
        let bannerText: String?
        let bannerTone: AudioModeBannerTone?
        let headerBadgeText: String?
        let emptyTitle: String
        let emptyDetail: String

        var scrollTargetMessageID: AudioTranscriptMessage.ID? {
            messages.last?.id
        }
    }

    struct ActionBar: Equatable {
        let primaryStatusChips: [String]
        let modeStatusTitle: String
        let modeStatusDetail: String
    }

    let hero: Hero
    let transcript: Transcript
    let conversation: Conversation
    let actionBar: ActionBar

    init(
        transcription: AudioModeTranscriptionViewData,
        conversation: AudioModeConversationViewData,
        isAIPageAvailable: Bool = true
    ) {
        let heroBadge = if !isAIPageAvailable {
            "Unavailable"
        } else {
            transcription.badgeText
        }

        let transcriptFootnote: String? = {
            guard transcription.transcriptHistoryCount > 0 else {
                return nil
            }

            let segmentLabel = transcription.transcriptHistoryCount == 1 ? "segment" : "segments"
            return "\(transcription.transcriptHistoryCount) saved \(segmentLabel) in this session"
        }()

        let conversationHeaderBadge: String? = {
            if conversation.isSending {
                return "Sending"
            }
            if conversation.isLLMDisabled {
                return "Disabled"
            }
            return nil
        }()

        let emptyTitle: String
        let emptyDetail: String
        if !isAIPageAvailable {
            emptyTitle = "AI is unavailable"
            emptyDetail = "Load the required Codex secrets in Settings before starting a voice session."
        } else if conversation.isLLMDisabled {
            emptyTitle = "Codex replies are turned off"
            emptyDetail = "Voice capture still works, but assistant responses stay paused until LLM access is enabled."
        } else {
            emptyTitle = "Codex activity will appear here"
            emptyDetail = "Committed voice segments are sent automatically, and replies or tool results stay pinned in this feed."
        }

        let chips = [heroBadge, conversationHeaderBadge, conversation.noteTargetStatusText].compactMap { $0 }

        self.hero = Hero(
            title: transcription.title,
            detail: transcription.detail,
            badgeText: heroBadge,
            tintState: transcription.displayState,
            microphoneSystemImage: transcription.microphoneSystemImage,
            micButtonLabel: transcription.micButtonLabel,
            isActionDisabled: !isAIPageAvailable || transcription.isActionDisabled,
            isRecording: transcription.isRecording
        )
        self.transcript = Transcript(
            title: transcription.transcriptTitle,
            iconName: transcription.transcriptIconName,
            badgeText: transcription.transcriptBadgeText,
            body: transcription.transcriptBody,
            footnote: transcriptFootnote
        )
        self.conversation = Conversation(
            messages: conversation.messages,
            bannerText: conversation.bannerText,
            bannerTone: conversation.bannerTone,
            headerBadgeText: conversationHeaderBadge,
            emptyTitle: emptyTitle,
            emptyDetail: emptyDetail
        )
        self.actionBar = ActionBar(
            primaryStatusChips: chips,
            modeStatusTitle: isAIPageAvailable ? AudioModeTransitionCopy.activeStatusTitle : "AI unavailable",
            modeStatusDetail: isAIPageAvailable ? AudioModeTransitionCopy.activeStatusDetail : "AI requires loaded Codex secrets before voice capture can start."
        )
    }
}
