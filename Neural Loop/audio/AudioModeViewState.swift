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

    var scrollTargetMessageID: AudioTranscriptMessage.ID? {
        messages.last?.id
    }

    var newestSpeakableMessage: AudioTranscriptMessage? {
        messages.last { message in
            switch message.role {
            case .assistant, .toolResult, .error:
                return message.playbackState.isReplayEligible
            case .user, .status:
                return false
            }
        }
    }
}

struct AudioModeTurnSummary: Equatable {
    let title: String
    let detail: String
    let badgeText: String?
    let tintState: AudioTranscriptionDisplayState
    let showsRecoveryCopy: Bool
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
        let switchButtonTitle: String
        let switchButtonAccessibilityHint: String
    }

    let hero: Hero
    let transcript: Transcript
    let conversation: Conversation
    let actionBar: ActionBar
    let turnSummary: AudioModeTurnSummary

    init(
        transcription: AudioModeTranscriptionViewData,
        conversation: AudioModeConversationViewData,
        turnState: AudioTurnState = .idle,
        isAudioModeAvailable: Bool = true
    ) {
        let turnSummary = AudioModeViewState.turnSummary(for: turnState)
        let usesTranscriptionAvailabilityCopy = transcription.displayState == .unavailable

        let heroBadge = if !isAudioModeAvailable {
            "Unavailable"
        } else if usesTranscriptionAvailabilityCopy {
            transcription.badgeText
        } else {
            turnSummary.badgeText ?? transcription.badgeText
        }
        let heroTitle = if !isAudioModeAvailable {
            "Audio Mode is unavailable"
        } else if usesTranscriptionAvailabilityCopy {
            transcription.title
        } else {
            turnSummary.title
        }
        let heroDetail = if !isAudioModeAvailable {
            "Return to manual mode to keep working while audio access is unavailable."
        } else if usesTranscriptionAvailabilityCopy {
            transcription.detail
        } else {
            turnSummary.detail
        }
        let heroTintState = if !isAudioModeAvailable {
            AudioTranscriptionDisplayState.unavailable
        } else if usesTranscriptionAvailabilityCopy {
            transcription.displayState
        } else {
            turnSummary.tintState
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
            title: heroTitle,
            detail: heroDetail,
            badgeText: heroBadge,
            tintState: heroTintState,
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
        let actionBarModeStatusTitle = if !isAudioModeAvailable {
            "Audio Mode unavailable"
        } else if usesTranscriptionAvailabilityCopy {
            transcription.title
        } else {
            turnSummary.title
        }
        let actionBarModeStatusDetail = if !isAudioModeAvailable {
            "Return to Manual Mode to keep working while audio access is unavailable."
        } else if usesTranscriptionAvailabilityCopy {
            transcription.detail
        } else {
            turnSummary.detail
        }
        self.actionBar = ActionBar(
            primaryStatusChips: chips,
            modeStatusTitle: actionBarModeStatusTitle,
            modeStatusDetail: actionBarModeStatusDetail,
            switchButtonTitle: AudioModeTransitionCopy.returnActionTitle,
            switchButtonAccessibilityHint: AudioModeTransitionCopy.returnAccessibilityHint
        )
        self.turnSummary = turnSummary
    }

    private static func turnSummary(for turnState: AudioTurnState) -> AudioModeTurnSummary {
        switch turnState {
        case .idle:
            return AudioModeTurnSummary(
                title: AudioModeTransitionCopy.idleStatusTitle,
                detail: AudioModeTransitionCopy.idleStatusDetail,
                badgeText: AudioModeTransitionCopy.idleStatusBadge,
                tintState: .inactive,
                showsRecoveryCopy: false
            )
        case .listening:
            return AudioModeTurnSummary(
                title: AudioModeTransitionCopy.listeningStatusTitle,
                detail: AudioModeTransitionCopy.listeningStatusDetail,
                badgeText: AudioModeTransitionCopy.listeningStatusBadge,
                tintState: .listening,
                showsRecoveryCopy: false
            )
        case .processing:
            return AudioModeTurnSummary(
                title: AudioModeTransitionCopy.processingStatusTitle,
                detail: AudioModeTransitionCopy.processingStatusDetail,
                badgeText: AudioModeTransitionCopy.processingStatusBadge,
                tintState: .transcribing,
                showsRecoveryCopy: false
            )
        case .speaking:
            return AudioModeTurnSummary(
                title: AudioModeTransitionCopy.speakingStatusTitle,
                detail: AudioModeTransitionCopy.speakingStatusDetail,
                badgeText: AudioModeTransitionCopy.speakingStatusBadge,
                tintState: .transcribing,
                showsRecoveryCopy: false
            )
        case .interrupting:
            return AudioModeTurnSummary(
                title: AudioModeTransitionCopy.interruptingStatusTitle,
                detail: AudioModeTransitionCopy.interruptingStatusDetail,
                badgeText: AudioModeTransitionCopy.interruptingStatusBadge,
                tintState: .cooldown,
                showsRecoveryCopy: true
            )
        case .suspended:
            return AudioModeTurnSummary(
                title: AudioModeTransitionCopy.recoveringStatusTitle,
                detail: AudioModeTransitionCopy.recoveringStatusDetail,
                badgeText: AudioModeTransitionCopy.recoveringStatusBadge,
                tintState: .cooldown,
                showsRecoveryCopy: true
            )
        }
    }
}
