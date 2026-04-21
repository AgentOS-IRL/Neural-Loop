import XCTest
@testable import Neural_Loop

final class AudioModeViewStateTests: XCTestCase {
    func testConversationScrollTargetIsNilWhenThereAreNoMessages() {
        let conversation = AudioModeConversationViewData(
            messages: [],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        XCTAssertNil(conversation.scrollTargetMessageID)
    }

    func testNewestSpeakableMessageIsNilWhenThereAreNoMessages() {
        let conversation = AudioModeConversationViewData(
            messages: [],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        XCTAssertNil(conversation.newestSpeakableMessage)
    }

    func testConversationScrollTargetUsesNewestMessageIDForSingleMessageFeed() {
        let messageID = UUID()
        let conversation = AudioModeConversationViewData(
            messages: [
                .init(id: messageID, role: .assistant, content: "Reply ready")
            ],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        XCTAssertEqual(conversation.scrollTargetMessageID, messageID)
    }

    func testNewestSpeakableMessageUsesSingleCodexResponse() {
        let messageID = UUID()
        let conversation = AudioModeConversationViewData(
            messages: [
                .init(id: messageID, role: .assistant, content: "Reply ready")
            ],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        XCTAssertEqual(conversation.newestSpeakableMessage?.id, messageID)
        XCTAssertEqual(conversation.newestSpeakableMessage?.content, "Reply ready")
    }

    func testConversationScrollTargetMovesToLatestMessageWhenMessagesAppend() {
        let firstMessage = AudioTranscriptMessage(id: UUID(), role: .user, content: "Start")
        let secondMessage = AudioTranscriptMessage(id: UUID(), role: .assistant, content: "Continue")

        let initialConversation = AudioModeConversationViewData(
            messages: [firstMessage],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )
        let appendedConversation = AudioModeConversationViewData(
            messages: [firstMessage, secondMessage],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        XCTAssertEqual(initialConversation.scrollTargetMessageID, firstMessage.id)
        XCTAssertEqual(appendedConversation.scrollTargetMessageID, secondMessage.id)
    }

    func testNewestSpeakableMessageMovesToLatestCodexOutputInMixedFeed() {
        let firstAssistant = AudioTranscriptMessage(id: UUID(), role: .assistant, content: "First reply")
        let statusMessage = AudioTranscriptMessage(id: UUID(), role: .status, content: "Sending to Codex...")
        let secondAssistant = AudioTranscriptMessage(id: UUID(), role: .assistant, content: "Second reply")
        let conversation = AudioModeConversationViewData(
            messages: [firstAssistant, statusMessage, secondAssistant],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        XCTAssertEqual(conversation.newestSpeakableMessage?.id, secondAssistant.id)
        XCTAssertEqual(conversation.newestSpeakableMessage?.role, .assistant)
    }

    func testMapsListeningStateIntoHeroTranscriptAndEmptyConversation() {
        let transcription = AudioModeTranscriptionViewData(
            displayState: .listening,
            title: "Listening for your next phrase",
            detail: "The session is still live and ready for the next segment.",
            badgeText: "Open session",
            transcriptTitle: "Listening for more",
            transcriptIconName: "waveform",
            transcriptBadgeText: "Listening",
            transcriptBody: "Listening for more speech...",
            microphoneSystemImage: "stop.fill",
            micButtonLabel: "Listening for more speech",
            isActionDisabled: false,
            isRecording: true,
            transcriptHistoryCount: 2
        )
        let conversation = AudioModeConversationViewData(
            messages: [],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        let state = AudioModeViewState(transcription: transcription, conversation: conversation, turnState: .listening)

        XCTAssertEqual(state.hero.title, AudioModeTransitionCopy.listeningStatusTitle)
        XCTAssertEqual(state.hero.detail, AudioModeTransitionCopy.listeningStatusDetail)
        XCTAssertEqual(state.hero.badgeText, AudioModeTransitionCopy.listeningStatusBadge)
        XCTAssertEqual(state.transcript.footnote, "2 saved segments in this session")
        XCTAssertEqual(state.conversation.emptyTitle, "Codex activity will appear here")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Listening"])
        XCTAssertEqual(state.actionBar.modeStatusTitle, AudioModeTransitionCopy.listeningStatusTitle)
        XCTAssertEqual(state.actionBar.switchButtonTitle, AudioModeTransitionCopy.returnActionTitle)
    }

    func testMapsSendingConversationIntoBannerAndHeaderBadge() {
        let transcription = AudioModeTranscriptionViewData(
            displayState: .transcribing,
            title: "Transcribing live speech",
            detail: "Speech is being converted into text and prepared for Codex.",
            badgeText: "Transcribing",
            transcriptTitle: "Transcribing",
            transcriptIconName: "waveform.and.mic",
            transcriptBadgeText: "Live",
            transcriptBody: "Create a follow-up task",
            microphoneSystemImage: "stop.fill",
            micButtonLabel: "Transcribing speech",
            isActionDisabled: false,
            isRecording: true,
            transcriptHistoryCount: 0
        )
        let conversation = AudioModeConversationViewData(
            messages: [.init(role: .user, content: "Create a follow-up task")],
            bannerText: "Sending to Codex...",
            bannerTone: .info,
            isSending: true,
            isLLMDisabled: false
        )

        let state = AudioModeViewState(transcription: transcription, conversation: conversation, turnState: .processing)

        XCTAssertEqual(state.conversation.bannerText, "Sending to Codex...")
        XCTAssertEqual(state.conversation.headerBadgeText, "Sending")
        XCTAssertEqual(state.hero.title, AudioModeTransitionCopy.processingStatusTitle)
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Processing", "Sending"])
        XCTAssertEqual(state.actionBar.modeStatusDetail, AudioModeTransitionCopy.processingStatusDetail)
    }

    func testMapsDisabledAudioModeIntoUnavailableEmptyState() {
        let transcription = AudioModeTranscriptionViewData(
            displayState: .unavailable,
            title: "Microphone unavailable",
            detail: "Speech transcription is unavailable on this device.",
            badgeText: "Mic unavailable",
            transcriptTitle: "Live transcript",
            transcriptIconName: "text.quote",
            transcriptBadgeText: "Issue",
            transcriptBody: "Speech transcription is unavailable on this device.",
            microphoneSystemImage: "mic.fill",
            micButtonLabel: "Mic unavailable",
            isActionDisabled: true,
            isRecording: false,
            transcriptHistoryCount: 0
        )
        let conversation = AudioModeConversationViewData(
            messages: [],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        let state = AudioModeViewState(
            transcription: transcription,
            conversation: conversation,
            isAudioModeAvailable: false
        )

        XCTAssertEqual(state.hero.title, "Audio Mode is unavailable")
        XCTAssertEqual(state.hero.badgeText, "Unavailable")
        XCTAssertEqual(state.conversation.emptyTitle, "Audio Mode is unavailable")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Unavailable"])
        XCTAssertEqual(state.actionBar.modeStatusTitle, "Audio Mode unavailable")
        XCTAssertEqual(state.actionBar.switchButtonAccessibilityHint, AudioModeTransitionCopy.returnAccessibilityHint)
    }

    func testMapsLLMDisabledConversationIntoWarningState() {
        let transcription = AudioModeTranscriptionViewData(
            displayState: .inactive,
            title: "Audio Mode",
            detail: "Voice stays active across pauses until you stop the session.",
            badgeText: "Ready",
            transcriptTitle: "Live transcript",
            transcriptIconName: "text.quote",
            transcriptBadgeText: "Ready",
            transcriptBody: "Tap the mic to start speaking.",
            microphoneSystemImage: "mic.fill",
            micButtonLabel: "Start Voice Detection",
            isActionDisabled: false,
            isRecording: false,
            transcriptHistoryCount: 0
        )
        let conversation = AudioModeConversationViewData(
            messages: [],
            bannerText: "LLM access is disabled.",
            bannerTone: .warning,
            isSending: false,
            isLLMDisabled: true
        )

        let state = AudioModeViewState(transcription: transcription, conversation: conversation, turnState: .idle)

        XCTAssertEqual(state.conversation.headerBadgeText, "Disabled")
        XCTAssertEqual(state.conversation.emptyTitle, "Codex replies are turned off")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Idle", "Disabled"])
    }

    func testMapsInterruptingAndSuspendedTurnStatesIntoRecoveryCopy() {
        let transcription = AudioModeTranscriptionViewData(
            displayState: .cooldown,
            title: "Audio Mode",
            detail: "Speech is paused while the session settles.",
            badgeText: "Recovering",
            transcriptTitle: "Live transcript",
            transcriptIconName: "text.quote",
            transcriptBadgeText: "Recovering",
            transcriptBody: "Waiting for the next segment...",
            microphoneSystemImage: "mic.fill",
            micButtonLabel: "Recovering",
            isActionDisabled: false,
            isRecording: false,
            transcriptHistoryCount: 0
        )
        let conversation = AudioModeConversationViewData(
            messages: [
                .init(role: .assistant, content: "Half of a reply", playbackState: .interrupted)
            ],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        let interruptedState = AudioModeViewState(
            transcription: transcription,
            conversation: conversation,
            turnState: .interrupting(UUID())
        )
        let suspendedState = AudioModeViewState(
            transcription: transcription,
            conversation: conversation,
            turnState: .suspended
        )

        XCTAssertEqual(interruptedState.hero.title, AudioModeTransitionCopy.interruptingStatusTitle)
        XCTAssertEqual(interruptedState.actionBar.modeStatusTitle, AudioModeTransitionCopy.interruptingStatusTitle)
        XCTAssertEqual(suspendedState.hero.title, AudioModeTransitionCopy.recoveringStatusTitle)
        XCTAssertEqual(suspendedState.actionBar.modeStatusDetail, AudioModeTransitionCopy.recoveringStatusDetail)
    }
}
