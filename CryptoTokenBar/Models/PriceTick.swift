import Foundation

struct PriceTick: Sendable {
    let pair: MarketPair
    let price: Decimal
    let timestamp: Date
    let volume24h: Decimal?
    let priceChange24h: Decimal?
    
    init(pair: MarketPair, price: Decimal, timestamp: Date = Date(), volume24h: Decimal? = nil, priceChange24h: Decimal? = nil) {
        self.pair = pair
        self.price = price
        self.timestamp = timestamp
        self.volume24h = volume24h
        self.priceChange24h = priceChange24h
    }
}

struct AggregatedPrice: Sendable {
    let symbol: String
    let price: Decimal
    let displayPrice: String
    let quoteMode: QuoteMode
    let priceChange24h: Decimal?
    let lastUpdate: Date
    let status: PriceStatus
    
    enum PriceStatus: Sendable {
        case live
        case stale
        case disconnected
        case unavailable
    }
}
