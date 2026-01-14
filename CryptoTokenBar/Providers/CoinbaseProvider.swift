import Foundation

final class CoinbaseProvider: StreamingProvider, @unchecked Sendable {
    
    let source: DataSourceType = .coinbase
    
    private var webSocket: WebSocketClient?
    private let throttler = TickThrottler()
    private let subscriptionDiff = SubscriptionDiff()
    
    private var continuation: AsyncStream<PriceTick>.Continuation?
    private var _priceStream: AsyncStream<PriceTick>?
    
    private var _isConnected = false
    
    private var wsURL: URL {
        URL(string: "wss://ws-feed.exchange.coinbase.com")!
    }
    
    private(set) var usdtRate: Decimal = 1.0
    private(set) var usdcRate: Decimal = 1.0
    
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
        guard !pairs.isEmpty else { return }
        
        let productIds = pairs.map { pair in
            "\(pair.base)-\(pair.quote)"
        }
        
        let request = CoinbaseSubscribeRequest(
            type: "subscribe",
            productIds: productIds,
            channels: ["ticker"]
        )
        let data = try JSONEncoder().encode(request)
        try await webSocket?.send(data)
    }
    
    func unsubscribe(from pairs: [MarketPair]) async throws {
        guard !pairs.isEmpty else { return }
        
        let productIds = pairs.map { pair in
            "\(pair.base)-\(pair.quote)"
        }
        
        let request = CoinbaseSubscribeRequest(
            type: "unsubscribe",
            productIds: productIds,
            channels: ["ticker"]
        )
        let data = try JSONEncoder().encode(request)
        try await webSocket?.send(data)
    }
    
    func subscribeToFXRates() async throws {
        debugLog("[Coinbase] Subscribing to FX rates")
        let request = CoinbaseSubscribeRequest(
            type: "subscribe",
            productIds: ["USDT-USD", "USDC-USD"],
            channels: ["ticker"]
        )
        let data = try JSONEncoder().encode(request)
        try await webSocket?.send(data)
        debugLog("[Coinbase] FX subscribe request sent")
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
            let ticker = try JSONDecoder().decode(CoinbaseTicker.self, from: data)
            guard ticker.type == "ticker" else {
                debugLog("[Coinbase] Received: \(text.prefix(80))")
                return
            }
            
            if ticker.productId == "USDT-USD" {
                if let price = Decimal(string: ticker.price) {
                    usdtRate = price
                    debugLog("[Coinbase] USDT rate: \(price)")
                }
                return
            }
            
            if ticker.productId == "USDC-USD" {
                if let price = Decimal(string: ticker.price) {
                    usdcRate = price
                    debugLog("[Coinbase] USDC rate: \(price)")
                }
                return
            }
            
            let components = ticker.productId.split(separator: "-")
            guard components.count == 2 else { return }
            
            let base = String(components[0])
            let quote = String(components[1])
            
            guard await throttler.shouldEmit(for: base) else { return }
            guard let price = Decimal(string: ticker.price) else { return }
            
            let pair = MarketPair(base: base, quote: quote, source: .coinbase)
            let tick = PriceTick(pair: pair, price: price, timestamp: Date())
            
            continuation?.yield(tick)
        } catch {
        }
    }
    
    private func handleDisconnect() async {
        _isConnected = false
        await webSocket?.scheduleReconnect(to: wsURL)
    }
}

private struct CoinbaseSubscribeRequest: Codable {
    let type: String
    let productIds: [String]
    let channels: [String]
    
    enum CodingKeys: String, CodingKey {
        case type
        case productIds = "product_ids"
        case channels
    }
}

private struct CoinbaseTicker: Codable {
    let type: String
    let productId: String
    let price: String
    let volume24h: String?
    let open24h: String?
    let low24h: String?
    let high24h: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case productId = "product_id"
        case price
        case volume24h = "volume_24h"
        case open24h = "open_24h"
        case low24h = "low_24h"
        case high24h = "high_24h"
    }
}
