import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class ConnectionManager {
    
    static let shared = ConnectionManager()
    
    private(set) var connectionStatus: ConnectionStatus = .disconnected
    private(set) var lastError: String?
    
    private var activeConnections = 0
    private let maxConnections = 3
    private let maxSubscriptionsPerConnection = 200
    
    enum ConnectionStatus: String {
        case connected
        case connecting
        case disconnected
        case error
        case backgroundPaused
    }
    
    private init() {
        setupAppStateObservers()
    }
    
    private func setupAppStateObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resumeConnections()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pauseForBackground()
            }
        }
    }
    
    func registerConnection() -> Bool {
        guard activeConnections < maxConnections else {
            lastError = "Maximum connections reached (\(maxConnections))"
            return false
        }
        activeConnections += 1
        connectionStatus = .connected
        return true
    }
    
    func unregisterConnection() {
        activeConnections = max(0, activeConnections - 1)
        if activeConnections == 0 {
            connectionStatus = .disconnected
        }
    }
    
    func validateSubscriptionCount(_ count: Int) -> Bool {
        if count > maxSubscriptionsPerConnection {
            lastError = "Subscription limit exceeded. Max: \(maxSubscriptionsPerConnection), requested: \(count)"
            return false
        }
        return true
    }
    
    func reportError(_ error: String) {
        lastError = error
        connectionStatus = .error
    }
    
    func clearError() {
        lastError = nil
        if activeConnections > 0 {
            connectionStatus = .connected
        }
    }
    
    private func pauseForBackground() {
        guard connectionStatus == .connected else { return }
        connectionStatus = .backgroundPaused
    }
    
    private func resumeConnections() {
        guard connectionStatus == .backgroundPaused else { return }
        connectionStatus = .connected
    }
}
