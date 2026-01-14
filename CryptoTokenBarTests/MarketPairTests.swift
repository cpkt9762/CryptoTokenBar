import Testing
@testable import CryptoTokenBar

@Suite("MarketPair Tests")
struct MarketPairTests {
    
    @Test("MarketPair symbol is correct")
    func pairSymbol() {
        let pair = MarketPair(base: "btc", quote: "usdt", source: .binance)
        
        #expect(pair.symbol == "BTCUSDT")
        #expect(pair.displaySymbol == "BTC")
    }
    
    @Test("TradingView symbol generation")
    func tradingViewSymbol() {
        let binancePair = MarketPair(base: "ETH", quote: "USDT", source: .binance)
        #expect(binancePair.tradingViewSymbol() == "BINANCE:ETHUSDT")
        
        let coinbasePair = MarketPair(base: "BTC", quote: "USD", source: .coinbase)
        #expect(coinbasePair.tradingViewSymbol() == "COINBASE:BTCUSD")
    }
    
    @Test("Exchange URL generation")
    func exchangeURLs() {
        let binancePair = MarketPair(base: "BTC", quote: "USDT", source: .binance)
        #expect(binancePair.exchangeURL()?.absoluteString.contains("binance.com") == true)
        
        let coinbasePair = MarketPair(base: "BTC", quote: "USD", source: .coinbase)
        #expect(coinbasePair.exchangeURL()?.absoluteString.contains("coinbase.com") == true)
    }
}
