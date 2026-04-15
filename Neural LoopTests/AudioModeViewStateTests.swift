import XCTest
@testable import Neural_Loop

final class AudioModeViewStateTests: XCTestCase {
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

        let state = AudioModeViewState(transcription: transcription, conversation: conversation)

        XCTAssertEqual(state.hero.badgeText, "Open session")
        XCTAssertEqual(state.transcript.footnote, "2 saved segments in this session")
        XCTAssertEqual(state.conversation.emptyTitle, "Codex activity will appear here")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Open session"])
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

        let state = AudioModeViewState(transcription: transcription, conversation: conversation)

        XCTAssertEqual(state.conversation.bannerText, "Sending to Codex...")
        XCTAssertEqual(state.conversation.headerBadgeText, "Sending")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Transcribing", "Sending"])
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

        XCTAssertEqual(state.hero.badgeText, "Unavailable")
        XCTAssertEqual(state.conversation.emptyTitle, "Audio Mode is unavailable")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Unavailable"])
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

        let state = AudioModeViewState(transcription: transcription, conversation: conversation)

        XCTAssertEqual(state.conversation.headerBadgeText, "Disabled")
        XCTAssertEqual(state.conversation.emptyTitle, "Codex replies are turned off")
        XCTAssertEqual(state.actionBar.primaryStatusChips, ["Ready", "Disabled"])
    }
}
