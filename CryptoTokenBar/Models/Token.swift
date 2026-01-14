import Foundation

struct Token: Identifiable, Codable, Hashable {
    let id: UUID
    var symbol: String
    var isVisible: Bool
    var sortOrder: Int
    
    init(id: UUID = UUID(), symbol: String, isVisible: Bool = true, sortOrder: Int = 0) {
        self.id = id
        self.symbol = symbol.uppercased()
        self.isVisible = isVisible
        self.sortOrder = sortOrder
    }
    
    static let defaultTokens: [Token] = [
        Token(symbol: "BTC", sortOrder: 0),
        Token(symbol: "ETH", sortOrder: 1),
        Token(symbol: "SOL", sortOrder: 2),
        Token(symbol: "BNB", sortOrder: 3),
        Token(symbol: "XMR", sortOrder: 4)
    ]
}
