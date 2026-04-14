//
//  ConnectivityManager.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 23/01/2026.
//
import WatchConnectivity
import SwiftUI
import Combine

final class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ConnectivityManager()

    @Published var receivedMessage: String = "No message yet"

    private override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Activation
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            print("WC activate error:", error)
        } else {
            print("WC activated:", activationState.rawValue)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    // MARK: - Receiving Messages
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.receivedMessage = message["text"] as? String ?? "Unknown"
        }
    }

    // MARK: - Sending Messages
    func sendMessage(_ text: String) {
        guard WCSession.default.isReachable else {
            print("Device not reachable")
            return
        }

        WCSession.default.sendMessage(["text": text], replyHandler: nil)
    }
}
