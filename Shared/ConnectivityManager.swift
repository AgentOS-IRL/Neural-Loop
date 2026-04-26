//
//  ConnectivityManager.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 23/01/2026.
//
import WatchConnectivity
import SwiftUI
import Combine

protocol WorkoutConnectivityProviding: AnyObject {
    func sendWorkoutSnapshot(_ snapshot: ActiveWorkoutSnapshot, completion: ((Result<Void, Error>) -> Void)?)
    func sendWorkoutAction(_ action: WorkoutWatchAction, completion: ((Result<Void, Error>) -> Void)?)
}

open class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate, WorkoutConnectivityProviding {
    public static let shared = ConnectivityManager()

    @Published public var receivedMessage: String = "No message yet"
    @Published public var lastSnapshot: ActiveWorkoutSnapshot?
    @Published public var lastAction: WorkoutWatchAction?
    @Published public var isReachable: Bool = WCSession.isSupported() ? WCSession.default.isReachable : false

    // Closure hooks for non-UI components
    public var snapshotHandler: ((ActiveWorkoutSnapshot) -> Void)?
    public var actionHandler: ((WorkoutWatchAction) -> Void)?
    public var errorHandler: ((Error) -> Void)?
    public var notReachableHandler: (() -> Void)?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum MessageType: String {
        case text = "text"
        case workoutSnapshot = "workoutSnapshot"
        case workoutAction = "workoutAction"
    }

    private struct MessageKey {
        static let type = "msgType"
        static let payload = "payload"
    }

    public override init() {
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
    public func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            print("WC activate error:", error)
        } else {
            print("WC activated:", activationState.rawValue)
            DispatchQueue.main.async {
                self.isReachable = session.isReachable
            }
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) { }
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    // MARK: - Receiving Messages
    public func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any]) {
        handleIncomingMessage(message)
    }

    public func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        handleIncomingMessage(message)
        replyHandler([:]) // Acknowledge with empty reply
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        let typeString = message[MessageKey.type] as? String
        let type = typeString.flatMap { MessageType(rawValue: $0) }

        if let type {
            handleTypedMessage(type: type, payload: message[MessageKey.payload])
        } else if let text = message["text"] as? String {
            // Legacy/Generic text message
            DispatchQueue.main.async {
                self.receivedMessage = text
            }
        } else {
            print("ConnectivityManager: Received unknown or malformed message")
        }
    }

    private func handleTypedMessage(type: MessageType, payload: Any?) {
        guard let data = payload as? Data else {
            print("ConnectivityManager: Missing data payload for type \(type.rawValue)")
            return
        }

        do {
            switch type {
            case .text:
                let text = try decoder.decode(String.self, from: data)
                DispatchQueue.main.async {
                    self.receivedMessage = text
                }
            case .workoutSnapshot:
                let snapshot = try decoder.decode(ActiveWorkoutSnapshot.self, from: data)
                DispatchQueue.main.async {
                    self.lastSnapshot = snapshot
                    self.snapshotHandler?(snapshot)
                }
            case .workoutAction:
                let action = try decoder.decode(WorkoutWatchAction.self, from: data)
                DispatchQueue.main.async {
                    self.lastAction = action
                    self.actionHandler?(action)
                }
            }
        } catch {
            print("ConnectivityManager: Decoding error for type \(type.rawValue): \(error)")
            DispatchQueue.main.async {
                self.errorHandler?(error)
            }
        }
    }

    // MARK: - Sending Messages
    open func sendMessage(_ text: String) {
        sendEncodable(type: .text, payload: text)
    }

    open func sendWorkoutSnapshot(_ snapshot: ActiveWorkoutSnapshot, completion: ((Result<Void, Error>) -> Void)? = nil) {
        sendEncodable(type: .workoutSnapshot, payload: snapshot, completion: completion)
    }

    open func sendWorkoutAction(_ action: WorkoutWatchAction, completion: ((Result<Void, Error>) -> Void)? = nil) {
        sendEncodable(type: .workoutAction, payload: action, completion: completion)
    }

    private func sendEncodable<T: Encodable>(type: MessageType, payload: T, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard WCSession.default.isReachable else {
            print("Device not reachable")
            DispatchQueue.main.async {
                self.notReachableHandler?()
                completion?(.failure(NSError(domain: "ConnectivityManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device not reachable"])))
            }
            return
        }

        do {
            let data = try encoder.encode(payload)
            let message: [String: Any] = [
                MessageKey.type: type.rawValue,
                MessageKey.payload: data
            ]

            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("ConnectivityManager: Send error: \(error)")
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
            })
            
            // Call success immediately as we are not expecting a reply.
            // If it fails later, the errorHandler will call completion with .failure.
            completion?(.success(()))
        } catch {
            print("ConnectivityManager: Encoding error: \(error)")
            DispatchQueue.main.async {
                completion?(.failure(error))
            }
        }
    }
}
