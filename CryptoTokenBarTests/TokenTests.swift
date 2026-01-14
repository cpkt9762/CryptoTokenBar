import Testing
@testable import CryptoTokenBar

@Suite("Token Model Tests")
struct TokenTests {
    
    @Test("Token initializes with correct values")
    func tokenInitialization() {
        let token = Token(symbol: "btc", isVisible: true, sortOrder: 0)
        
        #expect(token.symbol == "BTC")
        #expect(token.isVisible == true)
        #expect(token.sortOrder == 0)
    }
    
    @Test("Default tokens are correct")
    func defaultTokens() {
        let defaults = Token.defaultTokens
        
        #expect(defaults.count == 5)
        #expect(defaults[0].symbol == "BTC")
        #expect(defaults[1].symbol == "ETH")
        #expect(defaults[2].symbol == "SOL")
        #expect(defaults[3].symbol == "BNB")
        #expect(defaults[4].symbol == "XMR")
    }
}
