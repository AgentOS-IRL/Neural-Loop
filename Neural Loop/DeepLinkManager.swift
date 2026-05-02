//
//  DeepLinkManager.swift
//  Neural Loop
//
//  Created by Codex on 28/04/2026.
//

import Foundation
import Combine

/// Recognized deep-link destinations that can be triggered
/// by URL schemes (e.g. widgets or Shortcuts).
typealias AppDeepLink = NeuralLoopDeepLink

/// A lightweight singleton that holds pending deep-link actions
/// so the app can route them after launch or while already running.
@MainActor
final class DeepLinkManager: ObservableObject {

    static let shared = DeepLinkManager()

    /// When set, the app should navigate to the corresponding
    /// destination and then clear this value once handled.
    @Published var pendingDeepLink: AppDeepLink?

    /// Whether the AI/audio page should start recording
    /// as soon as it appears.
    @Published var shouldStartListening = false

    private init() {}

    // MARK: - URL handling

    /// Parses an incoming URL and updates internal state.
    /// Returns `true` if the URL was recognized.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "neural-loop" else { return false }

        let normalizedPath = url.path.isEmpty ? "/" : url.path

        // neural-loop://ai/listen
        if url.host == "ai" && normalizedPath == "/listen" {
            pendingDeepLink = .aiListen
            shouldStartListening = true
            return true
        }

        // neural-loop://fitness/workout
        if url.host == "fitness" && normalizedPath == "/workout" {
            pendingDeepLink = .fitnessActiveWorkout
            return true
        }

        // neural-loop://tasks
        if url.host == "tasks" && normalizedPath == "/" {
            pendingDeepLink = .tasks
            return true
        }

        // neural-loop://tasks/add
        if url.host == "tasks" && normalizedPath == "/add" {
            pendingDeepLink = .addTask
            return true
        }

        // neural-loop://notes/add
        if url.host == "notes" && normalizedPath == "/add" {
            pendingDeepLink = .addNote
            return true
        }

        // neural-loop://calendar
        if url.host == "calendar" && normalizedPath == "/" {
            pendingDeepLink = .calendar
            return true
        }

        // neural-loop://fitness
        if url.host == "fitness" && normalizedPath == "/" {
            pendingDeepLink = .fitnessHome
            return true
        }

        return false
    }

    /// Call once the deep-link destination has been reached
    /// so subsequent taps can still trigger routing.
    func clearPendingNavigation() {
        pendingDeepLink = nil
    }

    /// Call once the audio page has consumed the listen intent.
    func clearListeningIntent() {
        shouldStartListening = false
    }
}
