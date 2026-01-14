import Foundation
import Observation

func debugLog(_ message: String) {
    let logPath = "/tmp/crypto_debug.log"
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
final class PriceService {
    
    static let shared = PriceService()
    
    private var futuresProvider: BinanceFuturesProvider?
    private var fxProvider: CoinbaseProvider?
    
    private(set) var prices: [String: AggregatedPrice] = [:]
    private(set) var sparklines: [String: SparklineBuffer] = [:]
    private(set) var sparklineVersion: Int = 0
    
    private var priceTask: Task<Void, Never>?
    private var fxTask: Task<Void, Never>?
    
    private var usdtRate: Decimal = 1.0
    private var usdcRate: Decimal = 1.0
    private var currentQuote: QuoteMode = .usdt
    
    private init() {}
    
    func start(tokens: [Token], settings: AppSettings) async throws {
        stop()
        
        currentQuote = settings.quoteMode
        let visibleTokens = tokens.filter(\.isVisible)
        debugLog("[PriceService] Starting with \(visibleTokens.count) visible tokens")
        
        for token in visibleTokens {
            sparklines[token.symbol] = SparklineBuffer()
        }
        
        fxProvider = CoinbaseProvider()
        debugLog("[PriceService] Connecting to FX provider...")
        try await fxProvider?.connect()
        try await fxProvider?.subscribeToFXRates()
        debugLog("[PriceService] FX provider connected")
        startFXStream()
        
        let symbols = visibleTokens.map(\.symbol)
        if !symbols.isEmpty {
            debugLog("[PriceService] Connecting to futures provider for: \(symbols)")
            futuresProvider = BinanceFuturesProvider()
            try await futuresProvider?.connect(symbols: symbols)
            startPriceStream()
        }
        
        debugLog("[PriceService] Started successfully")
    }
    
    func stop() {
        priceTask?.cancel()
        priceTask = nil
        fxTask?.cancel()
        fxTask = nil
        
        Task {
            await fxProvider?.disconnect()
            await futuresProvider?.disconnect()
        }
        
        fxProvider = nil
        futuresProvider = nil
    }
    
    func updateSubscriptions(tokens: [Token], quote: QuoteMode) async throws {
        let visibleSymbols = tokens.filter(\.isVisible).map(\.symbol)
        try await futuresProvider?.updateSymbols(visibleSymbols)
        
        for symbol in visibleSymbols {
            if sparklines[symbol] == nil {
                sparklines[symbol] = SparklineBuffer()
            }
        }
    }
    
    private func startPriceStream() {
        guard let provider = futuresProvider else { return }
        
        priceTask = Task {
            for await tick in provider.priceStream {
                guard !Task.isCancelled else { break }
                await processTick(tick, quote: currentQuote)
            }
        }
    }
    
    private func startFXStream() {
        guard let provider = fxProvider else { return }
        
        fxTask = Task {
            for await _ in provider.priceStream {
                guard !Task.isCancelled else { break }
                usdtRate = provider.usdtRate
                usdcRate = provider.usdcRate
            }
        }
    }
    
    private func processTick(_ tick: PriceTick, quote: QuoteMode) async {
        let symbol = tick.pair.base
        
        if sparklines[symbol] == nil {
            sparklines[symbol] = SparklineBuffer()
        }
        sparklines[symbol]?.add(price: tick.price)
        sparklineVersion += 1
        
        let displayPrice = formatPrice(tick.price, quote: quote)
        let convertedPrice = convertToUSD(tick.price, fromQuote: tick.pair.quote)
        
        prices[symbol] = AggregatedPrice(
            symbol: symbol,
            price: convertedPrice,
            displayPrice: displayPrice,
            quoteMode: quote,
            priceChange24h: tick.priceChange24h,
            lastUpdate: tick.timestamp,
            status: .live
        )
    }
    
    private func formatPrice(_ price: Decimal, quote: QuoteMode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = price < 1 ? 6 : 2
        
        return formatter.string(from: price as NSDecimalNumber) ?? "$0.00"
    }
    
    private func convertToUSD(_ price: Decimal, fromQuote: String) -> Decimal {
        switch fromQuote.uppercased() {
        case "USDT":
            return price * usdtRate
        case "USDC":
            return price * usdcRate
        case "USD":
            return price
        default:
            return price
        }
    }
}
