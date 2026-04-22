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
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: AudioModeTheme.Metrics.sectionSpacing) {
                        AudioModeHeroCard(
                            state: viewState.hero,
                            isReduceMotionEnabled: reduceMotion,
                            isPulsing: pulse,
                            onTapMic: toggleMicrophone
                        )
                        .equatable()

                        contentLayout(for: geometry.size, viewState: viewState)
                    }
                    .padding(.horizontal, AudioModeTheme.Metrics.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 104)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    AudioModeActionBar(state: viewState.actionBar)
                    .equatable()
                    .padding(.horizontal, AudioModeTheme.Metrics.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 86)
                    .background(Color.clear)
                }
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

    @ViewBuilder
    private func contentLayout(for size: CGSize, viewState: AudioModeViewState) -> some View {
        if size.width >= 780 {
            HStack(alignment: .top, spacing: AudioModeTheme.Metrics.sectionSpacing) {
                VStack(spacing: AudioModeTheme.Metrics.sectionSpacing) {
                    AudioModeTranscriptCard(state: viewState.transcript)
                        .equatable()
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .top)

                AudioModeConversationCard(state: viewState.conversation)
                    .equatable()
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            VStack(spacing: AudioModeTheme.Metrics.sectionSpacing) {
                AudioModeTranscriptCard(state: viewState.transcript)
                    .equatable()
                AudioModeConversationCard(state: viewState.conversation)
                    .equatable()
            }
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
