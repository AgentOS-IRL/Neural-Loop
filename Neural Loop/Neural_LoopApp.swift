//
//  Neural_LoopApp.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//

import SwiftUI
import EventKit
import SwiftData
import UIKit
import UserNotifications

final class NeuralLoopAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let value = response.notification.request.content.userInfo["deepLink"] as? String,
              let url = URL(string: value) else { return }
        Task { @MainActor in
            DeepLinkManager.shared.handle(url)
        }
    }
}

@main
struct Neural_LoopApp: App {
    @UIApplicationDelegateAdaptor(NeuralLoopAppDelegate.self) private var appDelegate
    
    init() {
        if isRunningUnderTests() {
            return
        }

        let eventStore = EKEventStore()

        Task {
            do {
                try await eventStore.requestFullAccessToEvents()
                let _ = try NeuralLoopCalendarService.shared.createNeuralLoopCalendar()
                print("Calendar access granted")
            } catch {
                print("Calendar access denied: \(error)")
            }
        }

        // Handle deep link requests from Apple Watch
        ConnectivityManager.shared.deepLinkHandler = { destination in
            DeepLinkManager.shared.pendingDeepLink = destination
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    DeepLinkManager.shared.handle(url)
                }
        }.modelContainer(for: [
            CompletedRecurringTask.self,
            ParkingOutboxRecord.self,
            ParkingDiagnosticRecord.self
        ]).environmentObject(UnifiedDataModel.shared)
         .environmentObject(DeepLinkManager.shared)
    }
}
