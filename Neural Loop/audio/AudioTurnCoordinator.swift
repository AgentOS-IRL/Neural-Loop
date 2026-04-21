import Combine
import Foundation

@MainActor
final class AudioTurnCoordinator: ObservableObject {
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
        if muted {
            if let activeSpeechRequest {
                markSpeechEnded(for: activeSpeechRequest, reason: .canceled)
            }
            speechSynthesizer.stop(reason: .muted)
            stopInterruptionDetection()
            activeSpeechRequest = nil
            shouldResumeRecordingAfterSpeech = false
            updatePassiveTurnState()
        } else {
            syncSpeechPlayback()
        }
    }

    func interruptAssistantSpeech() {
        guard let request = activeSpeechRequest else {
            return
        }

        turnState = .interrupting(request.messageID)
        markSpeechEnded(for: request, reason: .interrupted)
        speechSynthesizer.stop(reason: .interrupted)
        stopInterruptionDetection()
        activeSpeechRequest = nil
        resumeRecordingAfterSpeechIfNeeded()
    }

    func tearDown() {
        transcriptionManager.stopRecording()
        transcriptionManager.onCommittedTranscript = nil
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
        speechSynthesizer.reset()
        stopInterruptionDetection()
        activeSpeechRequest = nil
        shouldResumeRecordingAfterSpeech = false
        spokenMessageRecords.removeAll()
        codexCoordinator.resetConversation()
    }

    private func syncSpeechPlayback() {
        guard activeSpeechRequest == nil else {
            return
        }

        guard let message = codexCoordinator.viewData.newestSpeakableMessage else {
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
            spokenMessageRecords[message.id] = AudioSpokenMessageRecord(
                messageID: message.id,
                endReason: .canceled
            )
            updatePassiveTurnState()
            return
        }

        pauseRecordingForSpeechPlaybackIfNeeded()
        let request = AudioSpeechRequest(messageID: message.id, text: message.content)
        activeSpeechRequest = request
        spokenMessageRecords[message.id] = AudioSpokenMessageRecord(
            messageID: message.id,
            requestID: request.id
        )
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
            startInterruptionDetectionIfNeeded()
        case .ended(let request, let reason):
            markSpeechEnded(for: request, reason: reason)
            stopInterruptionDetection()
            activeSpeechRequest = nil
            if reason == .finished || reason == .interrupted {
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
        record.endReason = reason
        spokenMessageRecords[request.messageID] = record
    }

    private func pauseRecordingForSpeechPlaybackIfNeeded() {
        guard transcriptionManager.isRecording, !shouldResumeRecordingAfterSpeech else {
            return
        }

        shouldResumeRecordingAfterSpeech = true
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
            self.updatePassiveTurnState()
        }
    }

    private func startInterruptionDetectionIfNeeded() {
        guard !isSpeechMuted, !isInterruptionDetectionRunning, activeSpeechRequest != nil else {
            return
        }

        isInterruptionDetectionRunning = true
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
                #if DEBUG
                debugPrint("Audio interruption detection failed to start: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func stopInterruptionDetection() {
        guard isInterruptionDetectionRunning else {
            return
        }

        interruptionDetectionSession.stop()
        isInterruptionDetectionRunning = false
    }

    private func handleInterruptionDetectionEvent(_ event: AudioInterruptionDetectionEvent) {
        guard case .speaking(let messageID) = turnState, let activeSpeechRequest, activeSpeechRequest.messageID == messageID else {
            return
        }

        switch event {
        case .possible:
            break
        case .confirmed:
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
        } else {
            turnState = .idle
        }
    }
}
