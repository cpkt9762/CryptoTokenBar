import Foundation

struct ScreenSaverToken: Identifiable, Hashable {
    let id = UUID()
    let symbol: String
    let name: String
    let quoteSymbol: String
    
    var marketSymbol: String {
        "\(symbol)\(quoteSymbol)"
    }
    
    static let defaultTokens: [ScreenSaverToken] = [
        ScreenSaverToken(symbol: "BTC", name: "Bitcoin", quoteSymbol: "USDT"),
        ScreenSaverToken(symbol: "ETH", name: "Ethereum", quoteSymbol: "USDT"),
        ScreenSaverToken(symbol: "SOL", name: "Solana", quoteSymbol: "USDT"),
        ScreenSaverToken(symbol: "BNB", name: "Binance Coin", quoteSymbol: "USDT"),
        ScreenSaverToken(symbol: "XMR", name: "Monero", quoteSymbol: "USDT"),
        ScreenSaverToken(symbol: "DOGE", name: "Dogecoin", quoteSymbol: "USDT"),
        ScreenSaverToken(symbol: "SUI", name: "Sui", quoteSymbol: "USDT")
    ]
}

struct ScreenSaverPrice: Identifiable, Hashable {
    let id: String
    let symbol: String
    let price: Decimal
    let changePercent: Decimal?
    
    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = price < 1 ? 6 : 2
        return formatter.string(from: price as NSDecimalNumber) ?? "$0.00"
    }
    
    var displayChange: String {
        guard let change = changePercent else { return "--" }
        let sign = change >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.multiplier = 1
        let value = formatter.string(from: change as NSDecimalNumber) ?? "0.00%"
        return sign + value
    }
}

// Lightweight sparkline buffer for screensaver (thread-safe)
final class ScreenSaverSparklineBuffer: @unchecked Sendable {
    private let maxPoints = 30
    private var buffer: [Decimal] = []
    private let lock = NSLock()
    
    init() {
        buffer.reserveCapacity(maxPoints)
    }
    
    func add(price: Decimal) {
        lock.lock()
        defer { lock.unlock() }
        
        buffer.append(price)
        if buffer.count > maxPoints {
            buffer.removeFirst()
        }
    }
    
    func getPoints() -> [Decimal] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
    
    func getNormalizedPoints() -> [Double] {
        let prices = getPoints()
        guard prices.count >= 2 else { return [] }
        
        let doubleValues = prices.compactMap { Double(truncating: $0 as NSDecimalNumber) }
        guard let minVal = doubleValues.min(),
              let maxVal = doubleValues.max(),
              maxVal > minVal else {
            return doubleValues.map { _ in 0.5 }
        }
        
        let range = maxVal - minVal
        return doubleValues.map { ($0 - minVal) / range }
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll()
    }
}
