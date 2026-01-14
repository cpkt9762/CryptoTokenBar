import Foundation
import Observation

@MainActor
@Observable
final class TokenStore {
    
    static let shared = TokenStore()
    
    private let key = "savedTokens"
    private(set) var tokens: [Token] = []
    
    private init() {
        loadTokens()
    }
    
    func loadTokens() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Token].self, from: data) {
            tokens = decoded.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            tokens = Token.defaultTokens
            saveTokens()
        }
    }
    
    func saveTokens() {
        if let data = try? JSONEncoder().encode(tokens) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func add(symbol: String) {
        guard !tokens.contains(where: { $0.symbol == symbol.uppercased() }) else { return }
        
        let newToken = Token(
            symbol: symbol,
            isVisible: true,
            sortOrder: tokens.count
        )
        tokens.append(newToken)
        saveTokens()
    }
    
    func remove(at offsets: IndexSet) {
        tokens.remove(atOffsets: offsets)
        reindex()
        saveTokens()
    }
    
    func move(from source: IndexSet, to destination: Int) {
        tokens.move(fromOffsets: source, toOffset: destination)
        reindex()
        saveTokens()
    }
    
    func toggleVisibility(for token: Token) {
        if let index = tokens.firstIndex(where: { $0.id == token.id }) {
            tokens[index].isVisible.toggle()
            saveTokens()
        }
    }
    
    var visibleTokens: [Token] {
        tokens.filter(\.isVisible).sorted { $0.sortOrder < $1.sortOrder }
    }
    
    private func reindex() {
        for i in tokens.indices {
            tokens[i].sortOrder = i
        }
    }
}
