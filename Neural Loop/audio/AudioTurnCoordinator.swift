import AVFoundation
import Combine
import Foundation
import OSLog

@MainActor
final class AudioTurnCoordinator: ObservableObject {
    private let logger = Logger(subsystem: "NeuralLoop", category: "AudioTurnCoordinator")
    @Published private(set) var turnState: AudioTurnState = .idle

    let transcriptionManager: AudioTranscriptionManager
    let codexCoordinator: AudioModeCodexCoordinator

    private let speechSynthesizer: any AudioModeSpeechSynthesizing
    private let interruptionDetectionSession: any AudioInterruptionDetectingSession
    private var cancellables: Set<AnyCancellable> = []
    private var spokenMessageRecords: [AudioTranscriptMessage.ID: AudioSpokenMessageRecord] = [:]
    private var activeSpeechRequest: AudioSpeechRequest?
    private var shouldResumeRecordingAfterSpeech = false
    private var isSpeechMuted = true
    private var isInterruptionDetectionRunning = false
    private var ttsStartedAt: ContinuousClock.Instant?
    private let ttsGracePeriodDuration: Duration = .milliseconds(400)

    var transcriptionViewData: AudioModeTranscriptionViewData {
        transcriptionManager.viewData
    }

    var conversationViewData: AudioModeConversationViewData {
        codexCoordinator.viewData
    }

    init(
        model: any AudioModeCodexModel,
        transcriptionManager: AudioTranscriptionManager? = nil,
        codexCoordinator: AudioModeCodexCoordinator? = nil,
        speechSynthesizer: (any AudioModeSpeechSynthesizing)? = nil,
        interruptionDetectionSession: (any AudioInterruptionDetectingSession)? = nil,
        isSpeechMuted: Bool = true
    ) {
        self.transcriptionManager = transcriptionManager ?? AudioTranscriptionManager()
        self.codexCoordinator = codexCoordinator ?? AudioModeCodexCoordinator(model: model)
        self.speechSynthesizer = speechSynthesizer ?? AudioModeSpeechSynthesizer()
        self.interruptionDetectionSession = interruptionDetectionSession ?? AudioInterruptionDetectionSession()
        self.isSpeechMuted = isSpeechMuted
        wireDependencies()
    }

    func refreshPermissionState() {
        transcriptionManager.refreshPermissionState()
    }

    func startListening() async {
        resetConversationState()
        await transcriptionManager.startRecording()
        updatePassiveTurnState()
    }

    func stopListeningAndReset() {
        transcriptionManager.stopRecording()
        resetConversationState()
        turnState = .idle
    }

    func toggleMicrophone() async {
        if transcriptionManager.isRecording {
            stopListeningAndReset()
        } else {
            await startListening()
        }
    }

    func setSpeechMuted(_ muted: Bool) {
        guard isSpeechMuted != muted else {
            return
        }

        isSpeechMuted = muted
        logger.debug("Speech mute changed to \(muted, privacy: .public)")
        if muted {
            if let activeSpeechRequest {
                markSpeechEnded(for: activeSpeechRequest, reason: .muted)
            }
            turnState = .suspended
            speechSynthesizer.stop(reason: .muted)
            stopInterruptionDetection()
            activeSpeechRequest = nil
            resumeRecordingAfterSpeechIfNeeded()
        } else {
            syncSpeechPlayback()
        }
    }

    func interruptAssistantSpeech() {
        guard let request = activeSpeechRequest else {
            return
        }

        turnState = .interrupting(request.messageID)
        logger.debug("Interrupting speech for message \(request.messageID.uuidString, privacy: .public)")
        markSpeechEnded(for: request, reason: .interrupted)
        speechSynthesizer.stop(reason: .interrupted)
        stopInterruptionDetection()
        activeSpeechRequest = nil
        ttsStartedAt = nil
        turnState = .suspended
        resumeRecordingAfterSpeechIfNeeded()
    }

    func tearDown() {
        transcriptionManager.stopRecording()
        transcriptionManager.onCommittedTranscript = nil
        stopInterruptionDetection()
        speechSynthesizer.stop(reason: .teardown)
        speechSynthesizer.reset()
        resetConversationState()
        turnState = .idle
    }

    private func wireDependencies() {
        transcriptionManager.onCommittedTranscript = { [weak self] transcript in
            Task { @MainActor in
                self?.codexCoordinator.handleCommittedTranscript(transcript)
                self?.turnState = .processing
            }
        }

        transcriptionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        codexCoordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        codexCoordinator.$conversationFeed
            .sink { [weak self] _ in
                self?.syncSpeechPlayback()
            }
            .store(in: &cancellables)
    }

    private func resetConversationState() {
        logger.debug("Resetting audio conversation state")
        speechSynthesizer.reset()
        stopInterruptionDetection()
        activeSpeechRequest = nil
        ttsStartedAt = nil
        shouldResumeRecordingAfterSpeech = false
        spokenMessageRecords.removeAll()
        codexCoordinator.resetConversation()
    }

    private func syncSpeechPlayback() {
        guard activeSpeechRequest == nil else {
            return
        }

        let blockedMessageIDs = Set(spokenMessageRecords.compactMap { messageID, record in
            record.isTerminal ? messageID : nil
        })

        guard let message = codexCoordinator.newestSpeakableMessage(excluding: blockedMessageIDs) else {
            if codexCoordinator.conversationFeed.isEmpty {
                spokenMessageRecords.removeAll()
            }
            updatePassiveTurnState()
            return
        }

        guard spokenMessageRecords[message.id] == nil else {
            updatePassiveTurnState()
            return
        }

        guard !isSpeechMuted else {
            markSpeechEnded(for: AudioSpeechRequest(messageID: message.id, text: message.content), reason: .muted)
            updatePassiveTurnState()
            return
        }

        logger.debug("Selected speakable message \(message.id.uuidString, privacy: .public)")
        pauseRecordingForSpeechPlaybackIfNeeded()
        let request = AudioSpeechRequest(messageID: message.id, text: message.content)
        activeSpeechRequest = request
        spokenMessageRecords[message.id] = AudioSpokenMessageRecord(messageID: message.id, requestID: request.id, didStart: false)
        codexCoordinator.markMessagePlaybackStarted(message.id)
        speechSynthesizer.speak(request) { [weak self] event in
            Task { @MainActor in
                self?.handleSpeechEvent(event)
            }
        }
    }

    private func handleSpeechEvent(_ event: AudioSpeechEvent) {
        guard event.request.id == activeSpeechRequest?.id else {
            return
        }

        switch event {
        case .started(let request):
            var record = spokenMessageRecords[request.messageID] ?? AudioSpokenMessageRecord(messageID: request.messageID)
            record.requestID = request.id
            record.didStart = true
            spokenMessageRecords[request.messageID] = record
            turnState = .speaking(request.messageID)
            ttsStartedAt = .now
            logger.debug("Speech started for message \(request.messageID.uuidString, privacy: .public)")
            startInterruptionDetectionIfNeeded()
        case .ended(let request, let reason):
            logger.debug("Speech ended for message \(request.messageID.uuidString, privacy: .public) with reason \(String(describing: reason), privacy: .public)")
            markSpeechEnded(for: request, reason: reason)
            stopInterruptionDetection()
            activeSpeechRequest = nil
            ttsStartedAt = nil
            if reason == .finished || reason == .interrupted || reason == .muted {
                resumeRecordingAfterSpeechIfNeeded()
            } else {
                shouldResumeRecordingAfterSpeech = false
                updatePassiveTurnState()
            }
        }
    }

    private func markSpeechEnded(for request: AudioSpeechRequest, reason: AudioSpeechEndReason) {
        var record = spokenMessageRecords[request.messageID] ?? AudioSpokenMessageRecord(messageID: request.messageID)
        record.requestID = request.id
        if record.endReason == .interrupted && reason != .interrupted {
            spokenMessageRecords[request.messageID] = record
            codexCoordinator.markMessagePlaybackInterrupted(request.messageID)
            return
        }

        record.endReason = reason
        record.didStart = record.didStart || reason == .finished || reason == .interrupted || reason == .muted
        spokenMessageRecords[request.messageID] = record
        switch reason {
        case .finished:
            codexCoordinator.markMessagePlaybackFinished(request.messageID)
        case .interrupted:
            codexCoordinator.markMessagePlaybackInterrupted(request.messageID)
        case .muted:
            codexCoordinator.markMessagePlaybackMuted(request.messageID)
        case .skipped:
            codexCoordinator.markMessagePlaybackSkipped(request.messageID)
        case .canceled, .teardown:
            codexCoordinator.markMessagePlaybackState(.canceled, for: request.messageID)
        case .failed:
            codexCoordinator.markMessagePlaybackFailed(request.messageID)
        }
    }

    private func pauseRecordingForSpeechPlaybackIfNeeded() {
        guard transcriptionManager.isRecording, !shouldResumeRecordingAfterSpeech else {
            return
        }

        shouldResumeRecordingAfterSpeech = true
        logger.debug("Pausing transcription while spoken reply is active")
        transcriptionManager.pauseRecording()
    }

    private func resumeRecordingAfterSpeechIfNeeded() {
        guard shouldResumeRecordingAfterSpeech else {
            updatePassiveTurnState()
            return
        }

        shouldResumeRecordingAfterSpeech = false
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            if !self.transcriptionManager.isRecording {
                await self.transcriptionManager.resumeRecording()
            }
            self.logger.debug("Full listening resumed")
            self.updatePassiveTurnState()
        }
    }

    private func startInterruptionDetectionIfNeeded() {
        guard !isSpeechMuted, !isInterruptionDetectionRunning, activeSpeechRequest != nil else {
            return
        }

        guard !isUsingBuiltInSpeaker else {
            logger.debug("Skipping interruption detection on built-in speaker route (echo unreliable)")
            return
        }

        isInterruptionDetectionRunning = true
        logger.debug("Arming interruption detection")
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.interruptionDetectionSession.start { [weak self] event in
                    Task { @MainActor in
                        self?.handleInterruptionDetectionEvent(event)
                    }
                }
                guard self.isInterruptionDetectionRunning else {
                    self.interruptionDetectionSession.stop()
                    return
                }
            } catch {
                self.isInterruptionDetectionRunning = false
                self.logger.debug("Interruption detection failed to start: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func stopInterruptionDetection() {
        guard isInterruptionDetectionRunning else {
            return
        }

        logger.debug("Disarming interruption detection")
        interruptionDetectionSession.stop()
        isInterruptionDetectionRunning = false
    }

    private var isUsingBuiltInSpeaker: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .contains { $0.portType == .builtInSpeaker }
    }

    private func handleInterruptionDetectionEvent(_ event: AudioInterruptionDetectionEvent) {
        guard case .speaking(let messageID) = turnState, let activeSpeechRequest, activeSpeechRequest.messageID == messageID else {
            return
        }

        switch event {
        case .possible:
            break
        case .confirmed:
            if let ttsStartedAt, ContinuousClock.now - ttsStartedAt < ttsGracePeriodDuration {
                logger.debug("Ignoring interruption during TTS grace period for message \(messageID.uuidString, privacy: .public)")
                break
            }
            logger.debug("Interruption confirmed for message \(messageID.uuidString, privacy: .public)")
            interruptAssistantSpeech()
        case .ended:
            break
        }
    }

    private func updatePassiveTurnState() {
        if activeSpeechRequest != nil {
            return
        }

        if codexCoordinator.isSending {
            turnState = .processing
        } else if transcriptionManager.isRecording {
            turnState = .listening
        } else if shouldResumeRecordingAfterSpeech {
            turnState = .suspended
        } else {
            turnState = .idle
        }
    }
}
