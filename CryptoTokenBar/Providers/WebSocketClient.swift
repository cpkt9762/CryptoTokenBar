import Foundation

// MARK: - TLS Bypass Delegate (for proxy environments)
private final class TLSBypassDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }
    
    private func handleChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        debugLog("[TLS] Challenge from: \(challenge.protectionSpace.host)")
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            SecTrustSetAnchorCertificatesOnly(serverTrust, false)
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

actor WebSocketClient {
    
    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    
    // Keep delegate alive
    private let sessionDelegate = TLSBypassDelegate()
    
    private(set) var isConnected = false
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 1.0
    
    private let messageHandler: @Sendable (URLSessionWebSocketTask.Message) async -> Void
    private let disconnectHandler: @Sendable () async -> Void
    
    init(
        messageHandler: @escaping @Sendable (URLSessionWebSocketTask.Message) async -> Void,
        disconnectHandler: @escaping @Sendable () async -> Void
    ) {
        self.session = URLSession(
            configuration: .default,
            delegate: sessionDelegate,
            delegateQueue: nil
        )
        self.messageHandler = messageHandler
        self.disconnectHandler = disconnectHandler
    }
    
    func connect(to url: URL) async throws {
        disconnect()
        
        debugLog("[WS] Connecting to \(url)")
        task = session.webSocketTask(with: url)
        task?.resume()
        
        try await Task.sleep(for: .seconds(1))
        
        isConnected = true
        reconnectAttempt = 0
        debugLog("[WS] Connection established")
        
        startReceiving()
        startPing()
    }
    
    func disconnect() {
        pingTask?.cancel()
        pingTask = nil
        
        receiveTask?.cancel()
        receiveTask = nil
        
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        
        isConnected = false
    }
    
    func send(_ message: String) async throws {
        guard let task = task else {
            throw StreamingError.disconnected
        }
        try await task.send(.string(message))
    }
    
    func send(_ data: Data) async throws {
        guard let task = task else {
            throw StreamingError.disconnected
        }
        try await task.send(.data(data))
    }
    
    private func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                do {
                    guard let task = await self.task else { break }
                    let message = try await task.receive()
                    await self.messageHandler(message)
                } catch {
                    debugLog("[WS] Receive error: \(error)")
                    if !Task.isCancelled {
                        await self.handleDisconnect()
                    }
                    break
                }
            }
        }
    }
    
    private func startPing() {
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self = self, let task = await self.task else { break }
                
                task.sendPing { error in
                    if error != nil {
                        Task {
                            await self.handleDisconnect()
                        }
                    }
                }
            }
        }
    }
    
    private func handleDisconnect() async {
        guard isConnected else { return }
        isConnected = false
        await disconnectHandler()
    }
    
    func scheduleReconnect(to url: URL) async {
        guard reconnectAttempt < maxReconnectAttempts else { return }
        
        reconnectAttempt += 1
        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1))
        let cappedDelay = min(delay, 60.0)
        
        try? await Task.sleep(for: .seconds(cappedDelay))
        
        if !Task.isCancelled {
            try? await connect(to: url)
        }
    }
}
