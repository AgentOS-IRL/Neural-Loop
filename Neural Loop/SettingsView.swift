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
    @State private var pendingRequests: [UNNotificationRequest] = []
    @AppStorage("isAudioMode") private var isAudioMode = false

    // Mirror the custom tab bar height (78) with extra cushion so list content stays above the overlay.
    private let bottomInsetHeight: CGFloat = 88

    private func loadPendingNotifications() async {
        let requests = await notificationTester.pendingNotificationRequests()
        await MainActor.run {
            self.pendingRequests = requests
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $isAudioMode) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audio Mode")
                                .font(.headline)
                            Text("Use a simplified, voice-first interface.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                } header: {
                    Text("App Mode")
                } footer: {
                    Text("Switching modes updates the main app shell immediately and remembers your choice across launches.")
                }

                Section {
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
        }
    }
}


#Preview {
    SettingsView()
}
