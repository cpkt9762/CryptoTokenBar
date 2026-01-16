import Foundation
import Observation

func ssDebugLog(_ message: String) {
    let logPath = "/tmp/crypto_screensaver.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data)
        }
    }
}

@MainActor
@Observable
final class ScreenSaverPriceStore {
    static let shared = ScreenSaverPriceStore()
    
    private(set) var prices: [String: ScreenSaverPrice] = [:]
    private(set) var sparklines: [String: ScreenSaverSparklineBuffer] = [:]
    private(set) var lastUpdated: Date?
    private(set) var statusMessage: String?
    private(set) var sparklineVersion: Int = 0
    private(set) var isDisconnected: Bool = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 1.0
    private var lastTickTime: Date = Date()
    private let staleThreshold: TimeInterval = 60
    
    private init() {
        for token in ScreenSaverToken.defaultTokens {
            sparklines[token.symbol] = ScreenSaverSparklineBuffer()
        }
    }
    
    func start() {
        stop()
        ssDebugLog("[ScreenSaver] Starting WSS connection")
        Task {
            await connect()
        }
    }
    
    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isDisconnected = false
        statusMessage = nil
    }
    
    private func connect() async {
        let tokens = ScreenSaverToken.defaultTokens
        let streams = tokens.map { "\($0.symbol.lowercased())usdt@miniTicker" }.joined(separator: "/")
        let urlString = "wss://fstream.binance.com/stream?streams=\(streams)"
        
        guard let url = URL(string: urlString) else {
            statusMessage = "Invalid URL"
            return
        }
        
        ssDebugLog("[ScreenSaver] Connecting to \(urlString)")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        try? await Task.sleep(for: .seconds(1))
        
        reconnectAttempt = 0
        isDisconnected = false
        statusMessage = nil
        lastTickTime = Date()
        
        ssDebugLog("[ScreenSaver] Connected")
        
        startReceiving()
        startPing()
        startWatchdog()
    }
    
    private func startReceiving() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, let task = self.webSocketTask else { break }
                
                do {
                    let message = try await task.receive()
                    await self.handleMessage(message)
                } catch {
                    ssDebugLog("[ScreenSaver] Receive error: \(error)")
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
                guard let self = self, let task = self.webSocketTask else { break }
                
                task.sendPing { error in
                    if error != nil {
                        Task { @MainActor in
                            await self.handleDisconnect()
                        }
                    }
                }
            }
        }
    }
    
    private func startWatchdog() {
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self = self, !Task.isCancelled else { break }
                
                if self.isDisconnected {
                    continue
                }
                
                let elapsed = Date().timeIntervalSince(self.lastTickTime)
                if elapsed > self.staleThreshold {
                    ssDebugLog("[ScreenSaver] Watchdog: no tick for \(Int(elapsed))s")
                    self.statusMessage = "Stale"
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await parseTickerMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                await parseTickerMessage(text)
            }
        @unknown default:
            break
        }
    }
    
    private func parseTickerMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }
        
        var ticker: FuturesMiniTicker?
        
        if let combined = try? JSONDecoder().decode(FuturesCombinedStream.self, from: data) {
            ticker = combined.data
        } else if let direct = try? JSONDecoder().decode(FuturesMiniTicker.self, from: data) {
            ticker = direct
        }
        
        guard let ticker else {
            if text.contains("\"id\"") || text.contains("\"result\"") { return }
            return
        }
        
        let symbol = extractSymbol(from: ticker.symbol)
        
        guard let price = Decimal(string: ticker.closePrice),
              let openPrice = Decimal(string: ticker.openPrice) else { return }
        
        let changePercent: Decimal? = openPrice != 0 ? ((price - openPrice) / openPrice) * 100 : nil
        
        lastTickTime = Date()
        lastUpdated = Date()
        statusMessage = nil
        
        if isDisconnected {
            isDisconnected = false
            ssDebugLog("[ScreenSaver] Connection restored")
        }
        
        prices[symbol] = ScreenSaverPrice(
            id: ticker.symbol,
            symbol: symbol,
            price: price,
            changePercent: changePercent
        )
        
        sparklines[symbol]?.add(price: price)
        sparklineVersion += 1
    }
    
    private func extractSymbol(from pairSymbol: String) -> String {
        if pairSymbol.hasSuffix("USDT") {
            return String(pairSymbol.dropLast(4))
        }
        return pairSymbol
    }
    
    private func handleDisconnect() async {
        guard !isDisconnected else { return }
        
        ssDebugLog("[ScreenSaver] Disconnected, scheduling reconnect...")
        
        receiveTask?.cancel()
        pingTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        await scheduleReconnect()
    }
    
    private func scheduleReconnect() async {
        guard reconnectAttempt < maxReconnectAttempts else {
            ssDebugLog("[ScreenSaver] Reconnect exhausted after \(maxReconnectAttempts) attempts")
            isDisconnected = true
            statusMessage = "$0"
            markAllPricesDisconnected()
            return
        }
        
        reconnectAttempt += 1
        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1))
        let cappedDelay = min(delay, 60.0)
        
        ssDebugLog("[ScreenSaver] Reconnect attempt \(reconnectAttempt)/\(maxReconnectAttempts) in \(cappedDelay)s")
        statusMessage = "Reconnecting..."
        
        try? await Task.sleep(for: .seconds(cappedDelay))
        
        if !Task.isCancelled {
            await connect()
        }
    }
    
    private func markAllPricesDisconnected() {
        for (symbol, _) in prices {
            prices[symbol] = ScreenSaverPrice(
                id: symbol,
                symbol: symbol,
                price: 0,
                changePercent: nil
            )
        }
        sparklineVersion += 1
    }
}

private struct FuturesCombinedStream: Codable {
    let stream: String
    let data: FuturesMiniTicker
}

private struct FuturesMiniTicker: Codable {
    let symbol: String
    let closePrice: String
    let openPrice: String
    
    enum CodingKeys: String, CodingKey {
        case symbol = "s"
        case closePrice = "c"
        case openPrice = "o"
    }
}
