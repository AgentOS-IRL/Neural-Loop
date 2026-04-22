//
//  AudioModeView.swift
//  Neural Loop
//
//  Created by Codex on 14/04/2026.
//

import SwiftUI

struct AudioModeView: View {
    @EnvironmentObject private var model: UnifiedDataModel
    @StateObject private var transcriptionManager = AudioTranscriptionManager()
    @StateObject private var coordinator: AudioModeCodexCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pulse = false

    @MainActor
    init(model: UnifiedDataModel = .shared) {
        _coordinator = StateObject(wrappedValue: AudioModeCodexCoordinator(model: model))
    }

    var body: some View {
        let conversationViewData = coordinator.viewData
        let viewState = AudioModeViewState(
            transcription: transcriptionManager.viewData,
            conversation: conversationViewData,
            isAIPageAvailable: model.canUseAudioMode
        )

        ZStack {
            ModeBackdropView()

            GeometryReader { geometry in
                VStack(spacing: 14) {
                    AudioModeHeroCard(state: viewState.hero)
                        .equatable()

                    AudioModeConversationCard(
                        state: viewState.conversation,
                        layout: .primaryFeed
                    )
                    .equatable()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .padding(.horizontal, AudioModeTheme.Metrics.screenPadding)
                .padding(.top, 20)
                .frame(maxWidth: min(geometry.size.width, AudioModeTheme.Metrics.chatMaxWidth))
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AudioModeVoiceInputBar(
                    micState: viewState.hero,
                    transcriptState: viewState.transcript,
                    actionBarState: viewState.actionBar,
                    isReduceMotionEnabled: reduceMotion,
                    isPulsing: pulse,
                    onTapMic: toggleMicrophone
                )
                .equatable()
                .padding(.horizontal, AudioModeTheme.Metrics.screenPadding)
                .frame(maxWidth: AudioModeTheme.Metrics.chatMaxWidth)
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
        .onDisappear {
            transcriptionManager.stopRecording()
            transcriptionManager.onCommittedTranscript = nil
            coordinator.resetConversation()
        }
    }

    private func toggleMicrophone() {
        Task {
            guard model.canUseAudioMode else {
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
    AudioModeView(model: model)
        .environmentObject(model)
}
