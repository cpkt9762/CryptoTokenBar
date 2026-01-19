import Foundation
import Observation
import OSLog

func debugLog(_ message: String) {
    AppLog.app.debug("\(message)")
    AppLog.appendToFile(message, path: "/tmp/crypto_debug.log")
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
    private(set) var isDisconnected: Bool = false
    
    private var priceTask: Task<Void, Never>?
    private var fxTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    
    private var usdtRate: Decimal = 1.0
    private var usdcRate: Decimal = 1.0
    private var currentQuote: QuoteMode = .usdt
    private var lastTickTime: Date = Date()
    private let staleThreshold: TimeInterval = 30
    private let staleConfirmationsRequired = 2
    private var consecutiveStaleChecks = 0
    
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
            startWatchdog()
        }
        
        debugLog("[PriceService] Started successfully")
    }
    
    func stop() {
        priceTask?.cancel()
        priceTask = nil
        fxTask?.cancel()
        fxTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        
        Task {
            await fxProvider?.disconnect()
            await futuresProvider?.disconnect()
        }
        
        fxProvider = nil
        futuresProvider = nil
        isDisconnected = false
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
        
        lastTickTime = Date()
        if isDisconnected {
            isDisconnected = false
            debugLog("[PriceService] Connection restored")
        }
        
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
    
    private func startWatchdog() {
        watchdogTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                
                if let provider = futuresProvider, provider.isReconnectExhausted {
                    if !isDisconnected {
                        isDisconnected = true
                        debugLog("[PriceService] Watchdog: reconnect exhausted, marking disconnected")
                        markAllPricesDisconnected()
                    }
                    continue
                }
                
                let elapsed = Date().timeIntervalSince(lastTickTime)
                if elapsed > staleThreshold {
                    consecutiveStaleChecks += 1
                } else {
                    consecutiveStaleChecks = 0
                }

                if consecutiveStaleChecks >= staleConfirmationsRequired && !isDisconnected {
                    debugLog("[PriceService] Watchdog: no tick for \(Int(elapsed))s, marking stale")
                    markAllPricesStale()
                }
            }
        }
    }
    
    private func markAllPricesDisconnected() {
        for (symbol, price) in prices {
            prices[symbol] = AggregatedPrice(
                symbol: symbol,
                price: 0,
                displayPrice: "$0",
                quoteMode: price.quoteMode,
                priceChange24h: nil,
                lastUpdate: price.lastUpdate,
                status: .disconnected
            )
        }
        sparklineVersion += 1
    }
    
    private func markAllPricesStale() {
        for (symbol, price) in prices {
            if price.status == .live {
                prices[symbol] = AggregatedPrice(
                    symbol: symbol,
                    price: price.price,
                    displayPrice: price.displayPrice,
                    quoteMode: price.quoteMode,
                    priceChange24h: price.priceChange24h,
                    lastUpdate: price.lastUpdate,
                    status: .stale
                )
            }
        }
        sparklineVersion += 1
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
