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
    }

    struct ActionBar: Equatable {
        let primaryStatusChips: [String]
        let modeStatusTitle: String
        let modeStatusDetail: String
        let switchButtonTitle: String
        let switchButtonAccessibilityHint: String
    }

    let hero: Hero
    let transcript: Transcript
    let conversation: Conversation
    let actionBar: ActionBar

    init(
        transcription: AudioModeTranscriptionViewData,
        conversation: AudioModeConversationViewData,
        isAudioModeAvailable: Bool = true
    ) {
        let heroBadge = if !isAudioModeAvailable {
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
        if !isAudioModeAvailable {
            emptyTitle = "Audio Mode is unavailable"
            emptyDetail = "Return to manual mode to keep working while audio access is unavailable."
        } else if conversation.isLLMDisabled {
            emptyTitle = "Codex replies are turned off"
            emptyDetail = "Voice capture still works, but assistant responses stay paused until LLM access is enabled."
        } else {
            emptyTitle = "Codex activity will appear here"
            emptyDetail = "Committed voice segments are sent automatically, and replies or tool results stay pinned in this feed."
        }

        let chips = [heroBadge, conversationHeaderBadge].compactMap { $0 }

        self.hero = Hero(
            title: transcription.title,
            detail: transcription.detail,
            badgeText: heroBadge,
            tintState: transcription.displayState,
            microphoneSystemImage: transcription.microphoneSystemImage,
            micButtonLabel: transcription.micButtonLabel,
            isActionDisabled: transcription.isActionDisabled,
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
            modeStatusTitle: isAudioModeAvailable ? AudioModeTransitionCopy.activeStatusTitle : "Audio Mode unavailable",
            modeStatusDetail: isAudioModeAvailable ? AudioModeTransitionCopy.activeStatusDetail : "Return to Manual Mode to keep working while audio access is unavailable.",
            switchButtonTitle: AudioModeTransitionCopy.returnActionTitle,
            switchButtonAccessibilityHint: AudioModeTransitionCopy.returnAccessibilityHint
        )
    }
}
