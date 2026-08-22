//
//  NotificationManager.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 21/01/2026.
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

@MainActor
protocol NotificationScheduling: AnyObject {
    func requestPermission() async -> Bool
    func refreshAuthorizationStatus() async
    func ensureAuthorizationStatus() async -> Bool
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        sound: UNNotificationSound,
        userInfo: [AnyHashable: Any]
    ) async
    func scheduleRepeatingNotification(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        sound: UNNotificationSound,
        userInfo: [AnyHashable: Any]
    ) async
    func replaceNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        sound: UNNotificationSound,
        userInfo: [AnyHashable: Any]
    ) async
    func replaceRepeatingNotification(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        sound: UNNotificationSound,
        userInfo: [AnyHashable: Any]
    ) async
    func clearNotification(id: String)
    func clearIndexedNotificationsAsync(prefix: String) async
}

@MainActor
final class NotificationManager: ObservableObject, NotificationScheduling {

    // MARK: - Logging

    private func log(_ message: String, error: Error? = nil) {
        if let error {
            print("🔴 [NotificationManager]", message, "-", error.localizedDescription)
        } else {
            print("🟡 [NotificationManager]", message)
        }
    }

    // MARK: - Published State

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Properties

    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    // MARK: - Init

    private init() {
        Task {
            await refreshAuthorizationStatus()
        }
    }
    
    // MARK: - UI Status Helpers
    
    var statusSymbol: String {
        switch authorizationStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .provisional:
            return "bell.badge.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .ephemeral:
            return "clock.circle.fill"
        @unknown default:
            return "exclamationmark.triangle.fill"
        }
    }

    var statusColor: Color {
        switch authorizationStatus {
        case .authorized:
            return .green
        case .provisional:
            return .blue
        case .denied:
            return .red
        case .notDetermined:
            return .gray
        case .ephemeral:
            return .orange
        @unknown default:
            return .yellow
        }
    }
    

    var statusText: String {
        switch authorizationStatus {
        case .authorized:
            return "Enabled"
        case .provisional:
            return "Quietly Enabled"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not Set"
        case .ephemeral:
            return "Temporary"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Permission Handling

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshAuthorizationStatus()
            log("Permission request completed. Granted: \(granted)")
            return granted
        } catch {
            log("Failed to request notification permission", error: error)
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        log("Authorization status refreshed: \(authorizationStatus.rawValue)")
    }

    func ensureAuthorizationStatus() async -> Bool {
        await refreshAuthorizationStatus()
        return isAuthorized
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized ||
        authorizationStatus == .provisional
    }

    // MARK: - Scheduling Notifications

    /// Schedule a one-time notification
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        sound: UNNotificationSound = .default,
        userInfo: [AnyHashable: Any] = [:]
    ) async {

        guard isAuthorized else {
            log("Attempted to schedule notification without permission. ID: \(id)")
            return
        }

        guard date > Date() else {
            log("Skipped one-time notification in the past. ID: \(id)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.userInfo = userInfo

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerDate,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            log("Scheduled one-time notification. ID: \(id)")
        } catch {
            log("Failed to schedule one-time notification. ID: \(id)", error: error)
        }
    }

    func scheduleImmediateParkingSuccess(clientEventID: UUID) async {
        await refreshAuthorizationStatus()
        guard isAuthorized else {
            log("Skipped parking notification because permission is not already granted.")
            return
        }

        let identifier = "parking.success.\(clientEventID.uuidString.lowercased())"
        let content = UNMutableNotificationContent()
        content.title = "Parked Car Saved"
        content.body = "Your parking location is ready in Maps."
        content.sound = .default
        content.userInfo = [
            "deepLink": "neural-loop://maps/parked/\(clientEventID.uuidString.lowercased())"
        ]

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        do {
            try await center.add(request)
            log("Scheduled parking success notification. ID: \(identifier)")
        } catch {
            log("Failed to schedule parking success notification. ID: \(identifier)", error: error)
        }
    }

    /// Schedule a repeating notification (daily / weekly)
    func scheduleRepeatingNotification(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        sound: UNNotificationSound = .default,
        userInfo: [AnyHashable: Any] = [:]
    ) async {

        guard isAuthorized else {
            log("Attempted to schedule repeating notification without permission. ID: \(id)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.userInfo = userInfo

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            log("Scheduled repeating notification. ID: \(id)")
        } catch {
            log("Failed to schedule repeating notification. ID: \(id)", error: error)
        }
    }

    func replaceNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        sound: UNNotificationSound = .default,
        userInfo: [AnyHashable: Any] = [:]
    ) async {
        clearNotification(id: id)
        await scheduleNotification(
            id: id,
            title: title,
            body: body,
            date: date,
            sound: sound,
            userInfo: userInfo
        )
    }

    func replaceRepeatingNotification(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        sound: UNNotificationSound = .default,
        userInfo: [AnyHashable: Any] = [:]
    ) async {
        clearNotification(id: id)
        await scheduleRepeatingNotification(
            id: id,
            title: title,
            body: body,
            dateComponents: dateComponents,
            sound: sound,
            userInfo: userInfo
        )
    }

    // MARK: - Clearing Notifications

    func clearNotification(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        log("Cleared pending notification. ID: \(id)")
    }

    func clearAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
        log("Cleared all pending notifications")
    }

    func clearAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
        log("Cleared all delivered notifications")
    }

    // MARK: - Notification Categories & Actions

    func registerCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Complete",
            options: [.authenticationRequired]
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "HABIT_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
        log("Notification categories registered")
    }

    // MARK: - Debug / Utilities

    func printPendingNotifications() {
        center.getPendingNotificationRequests { requests in
            if requests.isEmpty {
                self.log("No pending notifications")
            } else {
                requests.forEach {
                    print("🔔 Pending:", $0.identifier)
                }
            }
        }
    }
    
    func clearIndexedNotifications(prefix: String) {

        guard !prefix.isEmpty else {
            log("clearIndexedNotifications called with empty prefix — ignored")
            return
        }

        center.getPendingNotificationRequests { requests in

            let idsToRemove = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(prefix) }

            guard !idsToRemove.isEmpty else {
                self.log("No pending notifications found with prefix: \(prefix)")
                return
            }

            self.center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            self.log("Cleared \(idsToRemove.count) notifications with prefix: \(prefix)")
        }
    }
    
    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
    
    func clearIndexedNotificationsAsync(prefix: String) async {
        
        guard !prefix.isEmpty else {
            log("clearIndexedNotificationsAsync called with empty prefix — ignored")
            return
        }

        let requests = await center.pendingNotificationRequests()

        let idsToRemove = requests
            .map { $0.identifier }
            .filter { $0.hasPrefix(prefix) }

        guard !idsToRemove.isEmpty else {
            log("No pending notifications found with prefix: \(prefix)")
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        log("Cleared \(idsToRemove.count) notifications with prefix: \(prefix)")
    }
}
