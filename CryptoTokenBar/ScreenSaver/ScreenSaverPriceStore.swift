import Foundation
import Observation

@MainActor
@Observable
final class ScreenSaverPriceStore {
    static let shared = ScreenSaverPriceStore()
    
    private(set) var prices: [String: ScreenSaverPrice] = [:]
    private(set) var sparklines: [String: ScreenSaverSparklineBuffer] = [:]
    private(set) var lastUpdated: Date?
    private(set) var statusMessage: String?
    private(set) var sparklineVersion: Int = 0
    
    private let refreshInterval: TimeInterval = 10
    private var refreshTask: Task<Void, Never>?
    
    private init() {
        // Initialize sparkline buffers for all tokens
        for token in ScreenSaverToken.defaultTokens {
            sparklines[token.symbol] = ScreenSaverSparklineBuffer()
        }
    }
    
    func start() {
        stop()
        refreshTask = Task {
            while !Task.isCancelled {
                await fetchPrices()
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
            }
        }
    }
    
    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    private func fetchPrices() async {
        let tokens = ScreenSaverToken.defaultTokens
        let symbolMap = Dictionary(uniqueKeysWithValues: tokens.map { ($0.marketSymbol, $0.symbol) })
        let symbols = tokens.map { "\"\($0.marketSymbol)\"" }.joined(separator: ",")
        let query = "[\(symbols)]"
        
        guard var components = URLComponents(string: "https://api.binance.com/api/v3/ticker/24hr") else {
            statusMessage = "Invalid API URL"
            return
        }
        components.queryItems = [URLQueryItem(name: "symbols", value: query)]
        guard let url = components.url else {
            statusMessage = "Invalid API URL"
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let tickers = try JSONDecoder().decode([BinanceTicker].self, from: data)
            
            var updated: [String: ScreenSaverPrice] = [:]
            for ticker in tickers {
                guard let price = Decimal(string: ticker.lastPrice) else { continue }
                let change = Decimal(string: ticker.priceChangePercent)
                let baseSymbol = symbolMap[ticker.symbol] ?? ticker.symbol
                
                updated[baseSymbol] = ScreenSaverPrice(
                    id: ticker.symbol,
                    symbol: baseSymbol,
                    price: price,
                    changePercent: change
                )
                
                // Add price to sparkline buffer
                sparklines[baseSymbol]?.add(price: price)
            }
            
            prices = updated
            lastUpdated = Date()
            statusMessage = nil
            sparklineVersion += 1
        } catch {
            statusMessage = "Update failed"
        }
    }
}

private struct BinanceTicker: Decodable {
    let symbol: String
    let lastPrice: String
    let priceChangePercent: String
}
