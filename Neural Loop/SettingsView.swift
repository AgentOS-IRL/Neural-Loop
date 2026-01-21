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
