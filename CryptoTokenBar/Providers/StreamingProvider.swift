import Foundation

protocol StreamingProvider: AnyObject, Sendable {
    var source: DataSourceType { get }
    var isConnected: Bool { get }
    
    func connect() async throws
    func disconnect() async
    func subscribe(to pairs: [MarketPair]) async throws
    func unsubscribe(from pairs: [MarketPair]) async throws
    
    var priceStream: AsyncStream<PriceTick> { get }
}

enum StreamingError: Error, Sendable {
    case connectionFailed(underlying: Error?)
    case subscriptionFailed(pair: MarketPair, reason: String)
    case rateLimitExceeded
    case invalidResponse
    case disconnected
}

struct ExchangeRate: Sendable {
    let from: String
    let to: String
    let rate: Decimal
    let timestamp: Date
    
    static let defaultUSDRate = ExchangeRate(from: "USDT", to: "USD", rate: 1.0, timestamp: Date())
}
