import XCTest
@testable import Neural_Loop

final class AIModeViewStateTests: XCTestCase {
    func testConversationScrollTargetIsNilWhenThereAreNoMessages() {
        let conversation = AIModeConversationViewData(
            messages: [],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        XCTAssertNil(conversation.scrollTargetMessageID)
    }

    func testConversationScrollTargetUsesNewestMessageIDForSingleMessageFeed() {
        let messageID = UUID()
        let conversation = AIModeConversationViewData(
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

    func testConversationScrollTargetMovesToLatestMessageWhenMessagesAppend() {
        let firstMessage = AITranscriptMessage(id: UUID(), role: .user, content: "Start")
        let secondMessage = AITranscriptMessage(id: UUID(), role: .assistant, content: "Continue")

        let initialConversation = AIModeConversationViewData(
            messages: [firstMessage],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )
        let appendedConversation = AIModeConversationViewData(
            messages: [firstMessage, secondMessage],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        XCTAssertEqual(initialConversation.scrollTargetMessageID, firstMessage.id)
        XCTAssertEqual(appendedConversation.scrollTargetMessageID, secondMessage.id)
    }

    func testMapsListeningStateIntoHeroTranscriptAndEmptyConversation() {
        let transcription = AIModeTranscriptionViewData(
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
        let conversation = AIModeConversationViewData(
            messages: [],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        let state = AIModeViewState(transcription: transcription, conversation: conversation)

        XCTAssertEqual(state.hero.badgeText, "Open session")
        XCTAssertEqual(state.transcript.footnote, "2 saved segments in this session")
        XCTAssertEqual(state.conversation.emptyTitle, "Codex activity will appear here")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Open session"])
        XCTAssertEqual(state.actionBar.modeStatusTitle, AIModeTransitionCopy.activeStatusTitle)
    }

    func testMapsSendingConversationIntoBannerAndHeaderBadge() {
        let transcription = AIModeTranscriptionViewData(
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
        let conversation = AIModeConversationViewData(
            messages: [.init(role: .user, content: "Create a follow-up task")],
            bannerText: "Sending to Codex...",
            bannerTone: .info,
            isSending: true,
            isLLMDisabled: false
        )

        let state = AIModeViewState(transcription: transcription, conversation: conversation)

        XCTAssertEqual(state.conversation.bannerText, "Sending to Codex...")
        XCTAssertEqual(state.conversation.headerBadgeText, "Sending")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Transcribing", "Sending"])
        XCTAssertEqual(state.actionBar.modeStatusDetail, AIModeTransitionCopy.activeStatusDetail)
    }

    func testMapsDisabledAIModeIntoUnavailableEmptyState() {
        let transcription = AIModeTranscriptionViewData(
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
        let conversation = AIModeConversationViewData(
            messages: [],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false
        )

        let state = AIModeViewState(
            transcription: transcription,
            conversation: conversation,
            isAIPageAvailable: false
        )

        XCTAssertEqual(state.hero.badgeText, "Unavailable")
        XCTAssertTrue(state.hero.isActionDisabled)
        XCTAssertEqual(state.conversation.emptyTitle, "AI is unavailable")
        XCTAssertEqual(state.conversation.emptyDetail, "Load the required Codex secrets in Settings before starting a voice session.")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Unavailable"])
        XCTAssertEqual(state.actionBar.modeStatusTitle, "AI unavailable")
        XCTAssertEqual(state.actionBar.modeStatusDetail, "AI requires loaded Codex secrets before voice capture can start.")
    }

    func testMapsLLMDisabledConversationIntoWarningState() {
        let transcription = AIModeTranscriptionViewData(
            displayState: .inactive,
            title: "AI",
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
        let conversation = AIModeConversationViewData(
            messages: [],
            bannerText: "LLM access is disabled.",
            bannerTone: .warning,
            isSending: false,
            isLLMDisabled: true
        )

        let state = AIModeViewState(transcription: transcription, conversation: conversation)

        XCTAssertEqual(state.conversation.headerBadgeText, "Disabled")
        XCTAssertEqual(state.conversation.emptyTitle, "Codex replies are turned off")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Ready", "Disabled"])
    }

    func testMapsRecentNoteTargetIntoActionBarChip() {
        let transcription = AIModeTranscriptionViewData(
            displayState: .inactive,
            title: "AI",
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
        let conversation = AIModeConversationViewData(
            messages: [
                .init(
                    role: .toolResult,
                    content: "Work note created: Follow up",
                    toolResultKind: .workNoteCreated
                )
            ],
            bannerText: nil,
            bannerTone: nil,
            isSending: false,
            isLLMDisabled: false,
            noteTargetStatusText: "Notes: Work"
        )

        let state = AIModeViewState(transcription: transcription, conversation: conversation)

        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Ready", "Notes: Work"])
    }
}
