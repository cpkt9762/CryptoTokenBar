import Foundation

struct MarketPair: Hashable, Codable {
    let base: String
    let quote: String
    let source: DataSourceType
    
    var symbol: String {
        "\(base)\(quote)"
    }
    
    var displaySymbol: String {
        base
    }
    
    init(base: String, quote: String, source: DataSourceType) {
        self.base = base.uppercased()
        self.quote = quote.uppercased()
        self.source = source
    }
    
    func tradingViewSymbol() -> String? {
        let exchange: String
        switch source {
        case .binance:
            exchange = "BINANCE"
        case .coinbase:
            exchange = "COINBASE"
        case .bitstamp:
            exchange = "BITSTAMP"
        }
        return "\(exchange):\(base)\(quote)"
    }
    
    func exchangeURL() -> URL? {
        switch source {
        case .binance:
            return URL(string: "https://www.binance.com/en/trade/\(base)_\(quote)")
        case .coinbase:
            return URL(string: "https://www.coinbase.com/advanced-trade/spot/\(base)-\(quote)")
        case .bitstamp:
            return URL(string: "https://www.bitstamp.net/markets/\(base.lowercased())/\(quote.lowercased())/")
        }
    }
}
