//
//  AudioModeView.swift
//  Neural Loop
//
//  Created by Codex on 14/04/2026.
//

import SwiftUI

struct AudioModeView: View {
    @EnvironmentObject private var model: UnifiedDataModel
    @AppStorage("isAudioMode") private var isAudioMode = false
    @StateObject private var transcriptionManager = AudioTranscriptionManager()
    @StateObject private var coordinator: AudioModeCodexCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pulse = false

    @MainActor
    init(model: UnifiedDataModel = .shared) {
        _coordinator = StateObject(wrappedValue: AudioModeCodexCoordinator(model: model))
    }

    var body: some View {
        let viewState = AudioModeViewState(
            transcription: transcriptionManager.viewData,
            conversation: coordinator.viewData,
            isAudioModeAvailable: model.canUseAudioMode
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

                        contentLayout(for: geometry.size, viewState: viewState)
                    }
                    .padding(.horizontal, AudioModeTheme.Metrics.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 150)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    AudioModeActionBar(
                        state: viewState.actionBar,
                        onSwitchToManualMode: exitAudioMode
                    )
                    .padding(.horizontal, AudioModeTheme.Metrics.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(Color.clear)
                }
            }
        }
        .onAppear {
            transcriptionManager.refreshPermissionState()
            transcriptionManager.onCommittedTranscript = { [coordinator] transcript in
                coordinator.handleCommittedTranscript(transcript)
            }
            reconcileAuthorizationState()
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
        .onChange(of: model.secretsLoaded) { _, _ in
            reconcileAuthorizationState()
        }
        .onChange(of: model.canUseAudioMode) { _, _ in
            reconcileAuthorizationState()
        }
    }

    @ViewBuilder
    private func contentLayout(for size: CGSize, viewState: AudioModeViewState) -> some View {
        if size.width >= 780 {
            HStack(alignment: .top, spacing: AudioModeTheme.Metrics.sectionSpacing) {
                VStack(spacing: AudioModeTheme.Metrics.sectionSpacing) {
                    AudioModeTranscriptCard(state: viewState.transcript)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .top)

                AudioModeConversationCard(state: viewState.conversation)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            VStack(spacing: AudioModeTheme.Metrics.sectionSpacing) {
                AudioModeTranscriptCard(state: viewState.transcript)
                AudioModeConversationCard(state: viewState.conversation)
            }
        }
    }

    private func toggleMicrophone() {
        Task {
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

    private func exitAudioMode() {
        transcriptionManager.stopRecording()
        transcriptionManager.onCommittedTranscript = nil
        coordinator.resetConversation()
        withAnimation(.easeInOut(duration: 0.24)) {
            isAudioMode = false
        }
    }

    private func reconcileAuthorizationState() {
        guard model.secretsLoaded else {
            return
        }

        guard model.canUseAudioMode else {
            if isAudioMode {
                withAnimation(.easeInOut(duration: 0.24)) {
                    isAudioMode = false
                }
            } else {
                isAudioMode = false
            }
            return
        }
    }
}

#Preview {
    let model = UnifiedDataModel(autoStart: false)
    AudioModeView(model: model)
        .environmentObject(model)
}
