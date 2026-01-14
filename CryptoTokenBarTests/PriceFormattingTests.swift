import Testing
@testable import CryptoTokenBar

@Suite("Price Formatting Tests")
struct PriceFormattingTests {
    
    @Test("QuoteMode display labels are correct")
    func quoteModeLabels() {
        #expect(QuoteMode.usdt.displayLabel == "USDT")
        #expect(QuoteMode.usdc.displayLabel == "USDC")
        #expect(QuoteMode.usdApprox.displayLabel == "USD≈")
    }
    
    @Test("DataSource types are correct")
    func dataSourceTypes() {
        #expect(DataSourceType.binance.rawValue == "binance")
        #expect(DataSourceType.coinbase.rawValue == "coinbase")
        #expect(DataSourceType.bitstamp.rawValue == "bitstamp")
    }
    
    @Test("DisplayMode types are correct")
    func displayModeTypes() {
        #expect(DisplayMode.carousel.rawValue == "carousel")
        #expect(DisplayMode.verticalTicker.rawValue == "verticalTicker")
    }
}
