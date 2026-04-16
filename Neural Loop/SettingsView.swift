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
    @AppStorage(settingsDebugEnabledStorageKey) private var isDebugEnabled = false
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
            ZStack {
                settingsBackground

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Metrics.sectionSpacing) {
                        llmSection
                        appModeSection
                        systemSection
                        if shouldShowSettingsDebugSections(isDebugEnabled: isDebugEnabled) {
                            loadedSecretsSection
                            scheduledNotificationsSection
                        }
                        
                        VStack {
                            Text(ConnectivityManager.shared.receivedMessage)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Button {
                                ConnectivityManager.shared.sendMessage("Hello from iPhone 📱")
                            } label: {
                                Text("Send to Watch")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.accentGradient)
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, bottomInsetHeight + 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
            .onChange(of: isDebugEnabled) { _, newValue in
                guard newValue else { return }
                Task { await loadPendingNotifications() }
            }
        }
    }

    // MARK: - Sections

    private var llmSection: some View {
        settingsCard(title: "LLM") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: llmModeToggleBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LLM Access")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Enable LLM features only when the `codex_auth_token` secret is loaded.")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .tint(Color(red: 0.14, green: 0.49, blue: 0.53))

                Divider()
                    .background(AppTheme.borderGradient)

                VStack(alignment: .leading, spacing: 12) {
                    statusRow(
                        isOn: model.llm_enabled,
                        text: model.secretsLoaded ? (model.llm_enabled ? "LLM enabled" : "LLM disabled") : "Checking LLM entitlement..."
                    )

                    statusRow(
                        isOn: model.secretsLoaded && model.canUseAudioMode,
                        text: model.secretsLoaded ? (model.canUseAudioMode ? "Audio mode secrets present" : "Audio mode secrets missing") : "Refreshing secrets..."
                    )
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
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                    )
                }
                .disabled(isRefreshingSecrets)
                
                Text("LLM access is enabled only when the codex_auth_token secret exists and this switch is on. Use Refresh Secrets if the table changed externally.")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var appModeSection: some View {
        settingsCard(title: "App Mode") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: audioModeToggleBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio Mode")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Use a simplified, voice-first interface.")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .tint(Color(red: 0.14, green: 0.49, blue: 0.53))
                .disabled(!shouldEnableAudioModeToggle(secretsLoaded: model.secretsLoaded, canUseAudioMode: model.canUseAudioMode))

                Text(model.secretsLoaded ? "Audio mode requires both the codex_auth_token and chatgpt_account_id secrets to be present in public.secrets." : "Audio mode stays unavailable until secrets finish loading.")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var systemSection: some View {
        settingsCard(title: "System") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: model.canUseAudioMode ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(model.canUseAudioMode ? .green : AppTheme.textSecondary)
                    Text(model.secretsLoaded ? (model.canUseAudioMode ? "\(codexAuthTokenSecretKey) present" : "\(codexAuthTokenSecretKey) missing") : "Checking audio entitlement...")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Divider()
                    .background(AppTheme.borderGradient)

                HStack(spacing: 12) {
                    Image(systemName: notificationTester.statusSymbol)
                        .font(.title3)
                        .foregroundStyle(notificationTester.statusColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(notificationTester.statusText)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        Task { await notificationTester.refreshAuthorizationStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .accessibilityLabel("Refresh notification status")
                    .accessibilityHint("Checks the current authorization status for notifications")
                }

                VStack(alignment: .leading, spacing: 10) {
                    settingsButton(label: "Request Permission", systemImage: "checkmark.shield") {
                        Task { await notificationTester.requestPermission() }
                    }
                    .disabled(notificationTester.authorizationStatus == .authorized || notificationTester.authorizationStatus == .provisional)

                    settingsButton(label: "Send Test Notification", systemImage: "bell.badge") {
                        Task {
                            let date = Date().addingTimeInterval(30)
                            try? await notificationTester.scheduleNotification(
                                id: "test.notification",
                                title: "Neural Loop",
                                body: "This is a test notification ✅",
                                date: date
                            )
                        }
                    }

                    settingsButton(label: "Open iOS Settings", systemImage: "gearshape") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
                
                Text("Use “Send Test Notification” to verify notifications are working on your device.")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Divider()
                    .background(AppTheme.borderGradient)

                debugToggleRow
            }
        }
    }

    private var debugToggleRow: some View {
        Toggle(isOn: $isDebugEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Show loaded secrets and scheduled notifications.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .tint(Color(red: 0.14, green: 0.49, blue: 0.53))
    }

    private var loadedSecretsSection: some View {
        settingsCard(title: "Loaded Secrets") {
            VStack(alignment: .leading, spacing: 12) {
                if !model.secretsLoaded {
                    Text("Secrets are still loading")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                } else if model.loadedSecretKeys.isEmpty {
                    Text("No secrets loaded")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(model.loadedSecretKeys, id: \.self) { key in
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accentGradient)
                            Text(key)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }

                Text("This section intentionally shows secret names only. Secret values stay in app state and are not rendered here.")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var scheduledNotificationsSection: some View {
        settingsCard(title: "Scheduled Notifications") {
            VStack(alignment: .leading, spacing: 12) {
                if pendingRequests.isEmpty {
                    Text("No scheduled notifications")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(pendingRequests, id: \.identifier) { request in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(request.content.title)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text(request.content.body)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)

                            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                               let date = trigger.nextTriggerDate() {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(AppTheme.accentGradient)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if request.identifier != pendingRequests.last?.identifier {
                            Divider()
                                .background(AppTheme.borderGradient)
                        }
                    }
                }

                Button {
                    Task { await loadPendingNotifications() }
                } label: {
                    Label("Refresh Notifications", systemImage: "arrow.clockwise")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Components

    private var settingsBackground: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            Circle()
                .fill(AppTheme.glowColor.opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: 140, y: -300)

            Circle()
                .fill(Color.adaptive(light: Color.white.opacity(0.20), dark: Color.white.opacity(0.05)))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: -120, y: -350)
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.leading, 4)

            content()
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                        .fill(AppTheme.cardGradient)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                }
        }
    }

    private func statusRow(isOn: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isOn ? "checkmark.seal.fill" : "xmark.seal")
                .foregroundStyle(isOn ? .green : AppTheme.textSecondary)
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func settingsButton(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 20)
                Text(label)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 8)
        }
    }
}

func shouldEnableAudioModeToggle(
    secretsLoaded: Bool,
    canUseAudioMode: Bool
) -> Bool {
    secretsLoaded && canUseAudioMode
}

let settingsDebugEnabledStorageKey = "settingsDebugEnabled"

func shouldShowSettingsDebugSections(isDebugEnabled: Bool) -> Bool {
    isDebugEnabled
}


#Preview {
    SettingsView()
        .environmentObject(UnifiedDataModel(autoStart: false))
}
