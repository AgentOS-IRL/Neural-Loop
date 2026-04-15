//
//  SettingsView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 21/01/2026.
//

import SwiftUI
import Combine
import UserNotifications



struct SettingsView: View {
    @StateObject private var notificationTester = NotificationManager.shared
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var model: UnifiedDataModel
    @State private var pendingRequests: [UNNotificationRequest] = []
    @AppStorage("isAudioMode") private var isAudioMode = false
    @AppStorage(llmEnabledOverrideStorageKey) private var llmEnabledOverride = false
    @State private var isRefreshingSecrets = false

    // Mirror the custom tab bar height (78) with extra cushion so list content stays above the overlay.
    private let bottomInsetHeight: CGFloat = 88

    private func loadPendingNotifications() async {
        let requests = await notificationTester.pendingNotificationRequests()
        await MainActor.run {
            self.pendingRequests = requests
        }
    }

    private var audioModeToggleBinding: Binding<Bool> {
        Binding(
            get: {
                shouldEnableAudioModeToggle(
                    secretsLoaded: model.secretsLoaded,
                    canUseAudioMode: model.canUseAudioMode
                ) ? isAudioMode : false
            },
            set: { newValue in
                guard shouldEnableAudioModeToggle(
                    secretsLoaded: model.secretsLoaded,
                    canUseAudioMode: model.canUseAudioMode
                ) else {
                    isAudioMode = false
                    return
                }

                isAudioMode = newValue
            }
        )
    }

    private var llmModeToggleBinding: Binding<Bool> {
        Binding(
            get: { llmEnabledOverride },
            set: { newValue in
                llmEnabledOverride = newValue
                model.setLLMOverrideEnabled(newValue)
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: llmModeToggleBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LLM Access")
                                .font(.headline)
                            Text("Enable LLM features only when the `codex_auth_token` secret is loaded.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    HStack(spacing: 8) {
                        Image(systemName: model.llm_enabled ? "checkmark.seal.fill" : "xmark.seal")
                            .foregroundStyle(model.llm_enabled ? .green : .secondary)
                        Text(model.secretsLoaded ? (model.llm_enabled ? "LLM enabled" : "LLM disabled") : "Checking LLM entitlement...")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: model.secretsLoaded && model.hasCodexAuthTokenSecret ? "checkmark.seal.fill" : "xmark.seal")
                            .foregroundStyle(model.secretsLoaded && model.hasCodexAuthTokenSecret ? .green : .secondary)
                        Text(model.secretsLoaded ? (model.hasCodexAuthTokenSecret ? "\(codexAuthTokenSecretKey) present" : "\(codexAuthTokenSecretKey) missing") : "Refreshing secrets...")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        guard !isRefreshingSecrets else { return }
                        isRefreshingSecrets = true
                        Task { @MainActor in
                            defer { isRefreshingSecrets = false }
                            await model.refreshSecrets()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRefreshingSecrets {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh Secrets")
                        }
                    }
                    .disabled(isRefreshingSecrets)
                } header: {
                    Text("LLM")
                } footer: {
                    Text("LLM access is enabled only when the codex_auth_token secret exists and this switch is on. Use Refresh Secrets if the table changed externally.")
                }

                Section {
                    Toggle(isOn: audioModeToggleBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audio Mode")
                                .font(.headline)
                            Text("Use a simplified, voice-first interface.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(!shouldEnableAudioModeToggle(secretsLoaded: model.secretsLoaded, canUseAudioMode: model.canUseAudioMode))
                } header: {
                    Text("App Mode")
                } footer: {
                    Text(model.secretsLoaded ? "Audio mode requires the codex_auth_token secret to be present in public.secrets." : "Audio mode stays unavailable until secrets finish loading.")
                }

                Section {
                    HStack(spacing: 8) {
                        Image(systemName: model.canUseAudioMode ? "checkmark.seal.fill" : "xmark.seal")
                            .foregroundStyle(model.canUseAudioMode ? .green : .secondary)
                        Text(model.secretsLoaded ? (model.canUseAudioMode ? "\(codexAuthTokenSecretKey) present" : "\(codexAuthTokenSecretKey) missing") : "Checking audio entitlement...")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: notificationTester.statusSymbol)
                            .font(.title3)
                            .foregroundStyle(notificationTester.statusColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications")
                                .font(.headline)
                            Text(notificationTester.statusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            Task { await notificationTester.refreshAuthorizationStatus() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Refresh notification status")
                    }
                    .padding(.vertical, 4)

                    Button {
                        Task { await notificationTester.requestPermission() }
                    } label: {
                        Label("Request Permission", systemImage: "checkmark.shield")
                    }
                    .disabled(notificationTester.authorizationStatus == .authorized || notificationTester.authorizationStatus == .provisional)

                    Button {
                        Task {
                            let date = Date().addingTimeInterval(30)
                            try? await notificationTester.scheduleNotification(
                                id: "test.notification",
                                title: "Neural Loop",
                                body: "This is a test notification ✅",
                                date: date
                            )
                        }
                    } label: {
                        Label("Send Test Notification", systemImage: "bell.badge")
                    }

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label("Open iOS Settings", systemImage: "gearshape")
                    }
                } header: {
                    Text("System")
                } footer: {
                    Text("Use “Send Test Notification” to verify notifications are working on your device.")
                }

                Section {
                    if !model.secretsLoaded {
                        Text("Secrets are still loading")
                            .foregroundStyle(.secondary)
                    } else if model.loadedSecretKeys.isEmpty {
                        Text("No secrets loaded")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.loadedSecretKeys, id: \.self) { key in
                            Text(key)
                        }
                    }
                } header: {
                    Text("Loaded Secrets")
                } footer: {
                    Text("This section intentionally shows secret names only. Secret values stay in app state and are not rendered here.")
                }
                
                VStack{
                    Text(ConnectivityManager.shared.receivedMessage)
                        .font(.title)
                    Button("Send to Watch") {
                        print("Sending message to watch...")
                        ConnectivityManager.shared.sendMessage("Hello from iPhone 📱")
                    }
                }

                Section {
                    if pendingRequests.isEmpty {
                        Text("No scheduled notifications")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pendingRequests, id: \.identifier) { request in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(request.content.title)
                                    .font(.headline)

                                Text(request.content.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                                   let date = trigger.nextTriggerDate() {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button {
                        Task { await loadPendingNotifications() }
                    } label: {
                        Label("Refresh Scheduled Notifications", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Scheduled Notifications")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: bottomInsetHeight)
            }
            .navigationTitle("Settings")
            .task {
                await notificationTester.refreshAuthorizationStatus()
                await loadPendingNotifications()
            }
            .onAppear {
                if model.secretsLoaded, !model.canUseAudioMode {
                    isAudioMode = false
                }
            }
            .onChange(of: model.secretsLoaded) { _, _ in
                if model.secretsLoaded, !model.canUseAudioMode {
                    isAudioMode = false
                }
            }
            .onChange(of: model.canUseAudioMode) { _, _ in
                if model.secretsLoaded, !model.canUseAudioMode {
                    isAudioMode = false
                }
            }
        }
    }
}

func shouldEnableAudioModeToggle(
    secretsLoaded: Bool,
    canUseAudioMode: Bool
) -> Bool {
    secretsLoaded && canUseAudioMode
}


#Preview {
    SettingsView()
        .environmentObject(UnifiedDataModel(autoStart: false))
}
