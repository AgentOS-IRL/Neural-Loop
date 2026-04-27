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
    func sendWorkoutFinalizedResult(_ result: WorkoutFinalizedResult, completion: ((Result<Void, Error>) -> Void)?)
    func clearWorkoutSnapshot(sessionID: String, reason: ClearReason)
}

open class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate, WorkoutConnectivityProviding {
    public static let shared = ConnectivityManager()

    @Published public var receivedMessage: String = "No message yet"
    @Published public var lastSnapshot: ActiveWorkoutSnapshot?
    @Published public private(set) var lastClearedWorkout: ClearedWorkoutSnapshot?
    @Published public var lastAction: WorkoutWatchAction?
    @Published public var isReachable: Bool = WCSession.isSupported() ? WCSession.default.isReachable : false

    // Closure hooks for non-UI components
    public var snapshotHandler: ((ActiveWorkoutSnapshot) -> Void)?
    public var clearedWorkoutHandler: ((ClearedWorkoutSnapshot) -> Void)?
    public var actionHandler: ((WorkoutWatchAction) -> Void)?
    public var finalizationHandler: ((WorkoutFinalizedResult) -> Void)?
    public var errorHandler: ((Error) -> Void)?
    public var notReachableHandler: (() -> Void)?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum MessageType: String {
        case text = "text"
        case workoutSnapshot = "workoutSnapshot"
        case workoutAction = "workoutAction"
        case workoutFinalized = "workoutFinalized"
        case workoutSyncPayload = "workoutSyncPayload"
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
    
    open func checkApplicationContext() {
        guard WCSession.isSupported() else { return }
        handleIncomingMessage(WCSession.default.receivedApplicationContext)
    }

    // MARK: - Activation
    public func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            print("WC activate error:", error)
        } else {
            print("WC activated:", activationState.rawValue)
            DispatchQueue.main.async { [weak self] in
                self?.isReachable = session.isReachable
                self?.checkApplicationContext()
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

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingMessage(applicationContext)
    }

    public func session(_ session: WCSession, didReceive userInfo: [String : Any] = [:]) {
        handleIncomingMessage(userInfo)
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
            case .workoutFinalized:
                let result = try decoder.decode(WorkoutFinalizedResult.self, from: data)
                DispatchQueue.main.async {
                    self.finalizationHandler?(result)
                }
            case .workoutSyncPayload:
                let syncPayload = try decoder.decode(WorkoutSyncPayload.self, from: data)
                DispatchQueue.main.async {
                    switch syncPayload {
                    case .active(let snapshot):
                        self.lastSnapshot = snapshot
                        self.snapshotHandler?(snapshot)
                    case .cleared(let cleared):
                        self.lastSnapshot = nil
                        self.lastClearedWorkout = cleared
                        self.clearedWorkoutHandler?(cleared)
                    }
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
        let payload = WorkoutSyncPayload.active(snapshot)

        do {
            let encodedPayload = try encoder.encode(payload)
            try WCSession.default.updateApplicationContext([
                MessageKey.type: MessageType.workoutSyncPayload.rawValue,
                MessageKey.payload: encodedPayload
            ])
        } catch {
            print("ConnectivityManager: Error updating application context with snapshot: \(error)")
        }
        
        sendEncodable(type: .workoutSyncPayload, payload: payload, completion: completion)
    }

    open func sendWorkoutAction(_ action: WorkoutWatchAction, completion: ((Result<Void, Error>) -> Void)? = nil) {
        if !WCSession.default.isReachable {
            do {
                let data = try encoder.encode(action)
                WCSession.default.transferUserInfo([
                    MessageKey.type: MessageType.workoutAction.rawValue,
                    MessageKey.payload: data
                ])
                completion?(.success(()))
            } catch {
                completion?(.failure(error))
            }
            return
        }
        
        sendEncodable(type: .workoutAction, payload: action, completion: { result in
            switch result {
            case .success:
                completion?(.success(()))
            case .failure:
                do {
                    let data = try self.encoder.encode(action)
                    WCSession.default.transferUserInfo([
                        MessageKey.type: MessageType.workoutAction.rawValue,
                        MessageKey.payload: data
                    ])
                    completion?(.success(())) // queued successfully
                } catch {
                    print("Fallback transferUserInfo failed: \(error)")
                    completion?(.failure(error))
                }
            }
        })
    }

    open func sendWorkoutFinalizedResult(_ result: WorkoutFinalizedResult, completion: ((Result<Void, Error>) -> Void)? = nil) {
        sendEncodable(type: .workoutFinalized, payload: result, completion: completion)
    }

    /// Signals the watch that there is no active workout. The watch store
    /// subscribes to $lastSnapshot and clears itself when it becomes nil.
    open func clearWorkoutSnapshot(sessionID: String, reason: ClearReason) {
        DispatchQueue.main.async {
            self.lastSnapshot = nil
        }
        let clearedSnapshot = ClearedWorkoutSnapshot(sessionID: sessionID, reason: reason)
        let payload = WorkoutSyncPayload.cleared(clearedSnapshot)
        
        do {
            let encodedPayload = try encoder.encode(payload)
            try WCSession.default.updateApplicationContext([
                MessageKey.type: MessageType.workoutSyncPayload.rawValue,
                MessageKey.payload: encodedPayload
            ])
        } catch {
            print("ConnectivityManager: Error updating application context with cleared payload: \(error)")
        }
        
        sendEncodable(type: .workoutSyncPayload, payload: payload)
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

            WCSession.default.sendMessage(message, replyHandler: { _ in
                DispatchQueue.main.async {
                    completion?(.success(()))
                }
            }, errorHandler: { error in
                print("ConnectivityManager: Send error: \(error)")
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
            })
        } catch {
            print("ConnectivityManager: Encoding error: \(error)")
            DispatchQueue.main.async {
                completion?(.failure(error))
            }
        }
    }
}
