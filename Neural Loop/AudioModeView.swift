//
//  AudioModeView.swift
//  Neural Loop
//
//  Created by Codex on 14/04/2026.
//

import SwiftUI

struct AudioModeView: View {
    @AppStorage("isAudioMode") private var isAudioMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var pulse = false

    var body: some View {
        ZStack {
            ModeBackdropView()

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                VStack(spacing: 22) {
                    microphoneOrb

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
                }

                Spacer(minLength: 16)

                Button {
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
            guard !reduceMotion else { return }
            pulse = true
        }
    }

    private var microphoneOrb: some View {
        ZStack {
            if !reduceMotion {
                Circle()
                    .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 2)
                    .frame(width: 214, height: 214)
                    .scaleEffect(pulse ? 1.18 : 0.92)
                    .opacity(pulse ? 0.0 : 0.65)
                    .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .strokeBorder(Color.blue.opacity(0.22), lineWidth: 10)
                    .frame(width: 164, height: 164)
                    .scaleEffect(pulse ? 1.08 : 0.98)
                    .opacity(pulse ? 0.45 : 0.72)
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
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
                .frame(width: 178, height: 178)
                .shadow(color: .black.opacity(0.22), radius: 20, y: 10)

            Image(systemName: "mic.fill")
                .font(.system(size: 70, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        }
        .frame(width: 230, height: 230)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Microphone is ready for audio mode")
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
}
