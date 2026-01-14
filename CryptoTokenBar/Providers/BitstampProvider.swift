import Foundation

final class BitstampProvider: StreamingProvider, @unchecked Sendable {
    
    let source: DataSourceType = .bitstamp
    
    private var webSocket: WebSocketClient?
    private let throttler = TickThrottler()
    private let subscriptionDiff = SubscriptionDiff()
    
    private var continuation: AsyncStream<PriceTick>.Continuation?
    private var _priceStream: AsyncStream<PriceTick>?
    
    private var _isConnected = false
    private var currentQuote: String = "usd"
    
    private var wsURL: URL {
        URL(string: "wss://ws.bitstamp.net")!
    }
    
    var isConnected: Bool {
        _isConnected
    }
    
    var priceStream: AsyncStream<PriceTick> {
        if let stream = _priceStream {
            return stream
        }
        let stream = AsyncStream<PriceTick> { continuation in
            self.continuation = continuation
        }
        _priceStream = stream
        return stream
    }
    
    func connect() async throws {
        let ws = WebSocketClient(
            messageHandler: { [weak self] message in
                await self?.handleMessage(message)
            },
            disconnectHandler: { [weak self] in
                await self?.handleDisconnect()
            }
        )
        self.webSocket = ws
        try await ws.connect(to: wsURL)
        _isConnected = true
    }
    
    func disconnect() async {
        _isConnected = false
        await webSocket?.disconnect()
        webSocket = nil
    }
    
    func subscribe(to pairs: [MarketPair]) async throws {
        for pair in pairs {
            let channel = "live_trades_\(pair.base.lowercased())\(pair.quote.lowercased())"
            let request = BitstampSubscribeRequest(
                event: "bts:subscribe",
                data: BitstampSubscribeData(channel: channel)
            )
            let data = try JSONEncoder().encode(request)
            try await webSocket?.send(data)
        }
    }
    
    func unsubscribe(from pairs: [MarketPair]) async throws {
        for pair in pairs {
            let channel = "live_trades_\(pair.base.lowercased())\(pair.quote.lowercased())"
            let request = BitstampSubscribeRequest(
                event: "bts:unsubscribe",
                data: BitstampSubscribeData(channel: channel)
            )
            let data = try JSONEncoder().encode(request)
            try await webSocket?.send(data)
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await parseMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                await parseMessage(text)
            }
        @unknown default:
            break
        }
    }
    
    private func parseMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let event = try JSONDecoder().decode(BitstampEvent.self, from: data)
            
            guard event.event == "trade" else { return }
            guard let tradeData = event.data else { return }
            
            let channel = event.channel
            let symbol = extractSymbol(from: channel)
            
            guard await throttler.shouldEmit(for: symbol) else { return }
            
            let pair = MarketPair(base: symbol, quote: currentQuote.uppercased(), source: .bitstamp)
            let tick = PriceTick(pair: pair, price: tradeData.price, timestamp: Date())
            
            continuation?.yield(tick)
        } catch {
        }
    }
    
    private func extractSymbol(from channel: String) -> String {
        var name = channel
        if name.hasPrefix("live_trades_") {
            name = String(name.dropFirst("live_trades_".count))
        }
        
        let suffixes = ["usd", "eur", "gbp", "btc", "eth"]
        for suffix in suffixes {
            if name.hasSuffix(suffix) {
                return String(name.dropLast(suffix.count)).uppercased()
            }
        }
        return name.uppercased()
    }
    
    private func handleDisconnect() async {
        _isConnected = false
        await webSocket?.scheduleReconnect(to: wsURL)
    }
}

private struct BitstampSubscribeRequest: Codable {
    let event: String
    let data: BitstampSubscribeData
}

private struct BitstampSubscribeData: Codable {
    let channel: String
}

private struct BitstampEvent: Codable {
    let event: String
    let channel: String
    let data: BitstampTradeData?
}

private struct BitstampTradeData: Codable {
    let price: Decimal
    let amount: Decimal
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case price
        case amount
        case timestamp
    }
}
