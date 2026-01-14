import Foundation

final class BinanceProvider: StreamingProvider, @unchecked Sendable {
    
    let source: DataSourceType = .binance
    
    private var webSocket: WebSocketClient?
    private let throttler = TickThrottler()
    
    private var continuation: AsyncStream<PriceTick>.Continuation?
    private var _priceStream: AsyncStream<PriceTick>?
    
    private var currentQuote: String = "USDT"
    private var _isConnected = false
    
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
    
    private var currentStreamURL: URL?
    
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
        
        currentStreamURL = buildStreamURL(tokens: ["BTC", "ETH", "SOL", "BNB"], quote: currentQuote)
        try await ws.connect(to: currentStreamURL!)
        _isConnected = true
    }
    
    private func buildStreamURL(tokens: [String], quote: String) -> URL {
        let streams = tokens.map { "\($0.lowercased())\(quote.lowercased())@miniTicker" }.joined(separator: "/")
        return URL(string: "wss://fstream.binance.com/stream?streams=\(streams)")!
    }
    
    func disconnect() async {
        _isConnected = false
        await webSocket?.disconnect()
        webSocket = nil
    }
    
    func subscribe(to pairs: [MarketPair]) async throws {}
    
    func unsubscribe(from pairs: [MarketPair]) async throws {}
    
    func updateSubscriptions(for tokens: [Token], quote: QuoteMode) async throws {
        let quoteStr: String
        switch quote {
        case .usdt: quoteStr = "USDT"
        case .usdc: quoteStr = "USDC"
        case .usdApprox: quoteStr = "USDT"
        }
        
        let visibleTokens = tokens.filter(\.isVisible).map(\.symbol)
        let newURL = buildStreamURL(tokens: visibleTokens, quote: quoteStr)
        
        if currentStreamURL != newURL && !visibleTokens.isEmpty {
            await webSocket?.disconnect()
            currentStreamURL = newURL
            try await webSocket?.connect(to: newURL)
        }
        
        currentQuote = quoteStr
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
        
        var ticker: BinanceMiniTicker?
        
        if let combined = try? JSONDecoder().decode(BinanceCombinedStream.self, from: data) {
            ticker = combined.data
        } else if let direct = try? JSONDecoder().decode(BinanceMiniTicker.self, from: data) {
            ticker = direct
        }
        
        guard let ticker else {
            if text.contains("\"id\"") || text.contains("\"result\"") { return }
            return
        }
        
        let symbol = extractSymbol(from: ticker.symbol, quote: currentQuote)
        guard await throttler.shouldEmit(for: symbol) else { return }
        
        guard let price = Decimal(string: ticker.closePrice),
              let openPrice = Decimal(string: ticker.openPrice) else { return }
        
        let priceChange24h: Decimal? = openPrice != 0 ? ((price - openPrice) / openPrice) * 100 : nil
        
        let pair = MarketPair(base: symbol, quote: currentQuote, source: .binance)
        let tick = PriceTick(pair: pair, price: price, timestamp: Date(), priceChange24h: priceChange24h)
        
        debugLog("[Binance] Tick: \(symbol) = \(price), change: \(priceChange24h?.description ?? "nil")%")
        continuation?.yield(tick)
    }
    
    private func extractSymbol(from pairSymbol: String, quote: String) -> String {
        if pairSymbol.hasSuffix(quote) {
            return String(pairSymbol.dropLast(quote.count))
        }
        return pairSymbol
    }
    
    private func handleDisconnect() async {
        if let url = currentStreamURL {
            await webSocket?.scheduleReconnect(to: url)
        }
    }
}

private struct BinanceRequest: Codable {
    let method: String
    let params: [String]
    let id: Int
}

private struct BinanceCombinedStream: Codable {
    let stream: String
    let data: BinanceMiniTicker
}

private struct BinanceMiniTicker: Codable {
    let symbol: String
    let closePrice: String
    let openPrice: String
    let highPrice: String
    let lowPrice: String
    let volume: String
    let quoteVolume: String
    
    enum CodingKeys: String, CodingKey {
        case symbol = "s"
        case closePrice = "c"
        case openPrice = "o"
        case highPrice = "h"
        case lowPrice = "l"
        case volume = "v"
        case quoteVolume = "q"
    }
}
