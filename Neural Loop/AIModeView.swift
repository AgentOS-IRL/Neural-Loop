//
//  AIModeView.swift
//  Neural Loop
//
//  Created by Codex on 14/04/2026.
//

import SwiftUI

struct AIModeView: View {
    @EnvironmentObject private var model: UnifiedDataModel
    @StateObject private var transcriptionManager = AITranscriptionManager()
    @StateObject private var coordinator: AIModeCodexCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pulse = false

    @MainActor
    init(model: UnifiedDataModel = .shared) {
        _coordinator = StateObject(wrappedValue: AIModeCodexCoordinator(model: model))
    }

    var body: some View {
        let conversationViewData = coordinator.viewData
        let viewState = AIModeViewState(
            transcription: transcriptionManager.viewData,
            conversation: conversationViewData,
            isAIPageAvailable: model.canUseAIMode
        )

        ZStack {
            ModeBackdropView()

            GeometryReader { geometry in
                VStack(spacing: 14) {
                    AIModeHeroCard(state: viewState.hero)
                        .equatable()

                    AIModeConversationCard(
                        state: viewState.conversation,
                        layout: .primaryFeed
                    )
                    .equatable()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .padding(.horizontal, AIModeTheme.Metrics.screenPadding)
                .padding(.top, 20)
                .frame(maxWidth: min(geometry.size.width, AIModeTheme.Metrics.chatMaxWidth))
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AIModeVoiceInputBar(
                    micState: viewState.hero,
                    transcriptState: viewState.transcript,
                    actionBarState: viewState.actionBar,
                    isReduceMotionEnabled: reduceMotion,
                    isPulsing: pulse,
                    onTapMic: toggleMicrophone
                )
                .equatable()
                .padding(.horizontal, AIModeTheme.Metrics.screenPadding)
                .frame(maxWidth: AIModeTheme.Metrics.chatMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 86)
            }
        }
        .onAppear {
            transcriptionManager.refreshPermissionState()
            transcriptionManager.onCommittedTranscript = { [coordinator] transcript in
                coordinator.handleCommittedTranscript(transcript)
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .task {
            await startListeningFromDeepLinkIfNeeded()
        }
        .onChange(of: model.canUseAIMode) { _, canUseAIMode in
            guard canUseAIMode else { return }
            Task {
                await startListeningFromDeepLinkIfNeeded()
            }
        }
        .onDisappear {
            transcriptionManager.stopRecording()
            transcriptionManager.onCommittedTranscript = nil
            coordinator.resetConversation()
        }
    }

    private func startListeningFromDeepLinkIfNeeded() async {
        let deepLink = DeepLinkManager.shared
        guard deepLink.shouldStartListening else { return }

        // Give cold launches a moment to finish view setup before starting audio.
        try? await Task.sleep(for: .milliseconds(350))

        guard deepLink.shouldStartListening else { return }

        guard !transcriptionManager.isRecording else {
            deepLink.clearListeningIntent()
            return
        }

        guard model.canUseAIMode else { return }

        coordinator.resetConversation()
        transcriptionManager.onCommittedTranscript = { [coordinator] transcript in
            coordinator.handleCommittedTranscript(transcript)
        }
        await transcriptionManager.startRecording()
        deepLink.clearListeningIntent()
    }

    private func toggleMicrophone() {
        Task {
            guard model.canUseAIMode else {
                transcriptionManager.stopRecording()
                return
            }

            if transcriptionManager.isRecording {
                transcriptionManager.stopRecording()
                transcriptionManager.onCommittedTranscript = nil
                coordinator.resetConversation()
            } else {
                coordinator.resetConversation()
                transcriptionManager.onCommittedTranscript = { [coordinator] transcript in
                    coordinator.handleCommittedTranscript(transcript)
                }
                await transcriptionManager.startRecording()
            }
        }
    }
}

#Preview {
    let model = UnifiedDataModel(autoStart: false)
    AIModeView(model: model)
        .environmentObject(model)
}
