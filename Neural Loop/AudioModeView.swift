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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var pulse = false

    var body: some View {
        ZStack {
            ModeBackdropView()

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                VStack(spacing: 22) {
                    microphoneButton

                    VStack(spacing: 10) {
                        Text("Audio Mode")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("A simplified voice-first interface is active.")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .accessibilityElement(children: .combine)

                    transcriptCard
                }

                Spacer(minLength: 16)

                Button {
                    transcriptionManager.stopRecording()
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isAudioMode = false
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.grid.2x2")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Switch to Manual Mode")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .foregroundStyle(.black)
                    .background(switchBackBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.32 : 0.24),
                        radius: 18,
                        y: 10
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch to Manual Mode")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .onAppear {
            transcriptionManager.refreshPermissionState()
            reconcileAuthorizationState()
            guard !reduceMotion else { return }
            pulse = true
        }
        .onDisappear {
            transcriptionManager.stopRecording()
        }
        .onChange(of: model.secretsLoaded) { _, _ in
            reconcileAuthorizationState()
        }
        .onChange(of: model.canUseAudioMode) { _, _ in
            reconcileAuthorizationState()
        }
    }

    private var microphoneButton: some View {
        Button {
            Task {
                await transcriptionManager.toggleRecording()
            }
        } label: {
            ZStack {
                if !reduceMotion {
                    Circle()
                        .strokeBorder(micOuterColor.opacity(micOuterOpacity), lineWidth: 2)
                        .frame(width: 214, height: 214)
                        .scaleEffect(micOuterScale)
                        .opacity(micOuterVisibility)
                        .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: pulse)

                    Circle()
                        .strokeBorder(micInnerColor.opacity(micInnerOpacity), lineWidth: 10)
                        .frame(width: 164, height: 164)
                        .scaleEffect(micInnerScale)
                        .opacity(micInnerVisibility)
                        .animation(.easeInOut(duration: 1.55).repeatForever(autoreverses: true), value: pulse)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                transcriptionManager.sessionState == .inactive ? Color.white.opacity(0.18) : Color.white.opacity(0.28),
                                lineWidth: 1
                            )
                    }
                    .frame(width: 178, height: 178)
                    .shadow(color: .black.opacity(0.22), radius: 20, y: 10)

                Image(systemName: transcriptionManager.microphoneSystemImage)
                    .font(.system(size: transcriptionManager.sessionState == .inactive ? 70 : 58, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
            }
            .frame(width: 230, height: 230)
        }
        .buttonStyle(.plain)
        .disabled(transcriptionManager.isActionDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(transcriptionManager.micButtonLabel)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: transcriptCardSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))

                Text(transcriptCardTitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                if transcriptionManager.isTranscriptFinal {
                    Text("Final")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                } else if transcriptionManager.sessionState == .cooldownPending {
                    Text("Cooldown")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Text(transcriptionManager.transcriptCardText)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .accessibilityLabel(transcriptionManager.transcriptCardText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.92))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
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

    private var micOuterColor: Color {
        switch transcriptionManager.sessionState {
        case .inactive:
            return .cyan
        case .checking, .listening:
            return .cyan
        case .transcribing:
            return .mint
        case .cooldownPending:
            return .orange
        }
    }

    private var micOuterOpacity: Double {
        switch transcriptionManager.sessionState {
        case .inactive:
            return 0.35
        case .checking, .listening:
            return 0.48
        case .transcribing:
            return 0.7
        case .cooldownPending:
            return 0.6
        }
    }

    private var micOuterScale: CGFloat {
        switch transcriptionManager.sessionState {
        case .inactive:
            return pulse ? 1.18 : 0.92
        case .checking, .listening:
            return pulse ? 1.14 : 0.96
        case .transcribing:
            return pulse ? 1.24 : 0.98
        case .cooldownPending:
            return pulse ? 1.08 : 0.98
        }
    }

    private var micOuterVisibility: Double {
        switch transcriptionManager.sessionState {
        case .inactive:
            return pulse ? 0.0 : 0.65
        case .checking, .listening:
            return 0.95
        case .transcribing:
            return 0.98
        case .cooldownPending:
            return 0.88
        }
    }

    private var micInnerColor: Color {
        switch transcriptionManager.sessionState {
        case .inactive:
            return .blue
        case .checking, .listening:
            return .blue
        case .transcribing:
            return .green
        case .cooldownPending:
            return .orange
        }
    }

    private var micInnerOpacity: Double {
        switch transcriptionManager.sessionState {
        case .inactive:
            return 0.22
        case .checking, .listening:
            return 0.34
        case .transcribing:
            return 0.5
        case .cooldownPending:
            return 0.42
        }
    }

    private var micInnerScale: CGFloat {
        switch transcriptionManager.sessionState {
        case .inactive:
            return pulse ? 1.08 : 0.98
        case .checking, .listening:
            return pulse ? 1.08 : 1.0
        case .transcribing:
            return pulse ? 1.14 : 1.04
        case .cooldownPending:
            return pulse ? 1.05 : 1.0
        }
    }

    private var micInnerVisibility: Double {
        switch transcriptionManager.sessionState {
        case .inactive:
            return 0.72
        case .checking, .listening:
            return 0.88
        case .transcribing:
            return 0.94
        case .cooldownPending:
            return 0.9
        }
    }

    private var transcriptCardSymbol: String {
        switch transcriptionManager.sessionState {
        case .inactive:
            return "text.quote"
        case .checking, .listening:
            return "waveform"
        case .transcribing:
            return "waveform.and.mic"
        case .cooldownPending:
            return "clock.arrow.circlepath"
        }
    }

    private var transcriptCardTitle: String {
        switch transcriptionManager.sessionState {
        case .inactive:
            return "Transcript"
        case .checking:
            return "Checking"
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .cooldownPending:
            return "Cooldown"
        }
    }

    private var switchBackBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.79, green: 0.93, blue: 1.0),
                Color(red: 0.55, green: 0.83, blue: 0.99)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    AudioModeView()
        .environmentObject(UnifiedDataModel(autoStart: false))
}
