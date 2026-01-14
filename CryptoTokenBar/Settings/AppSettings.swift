import Foundation
import Observation

enum QuoteMode: String, CaseIterable, Codable {
    case usdt = "USDT"
    case usdc = "USDC"
    case usdApprox = "USD≈"
    
    var displayLabel: String {
        rawValue
    }
}

enum DisplayMode: String, CaseIterable, Codable {
    case carousel
    case verticalTicker
}

enum DataSourceType: String, CaseIterable, Codable {
    case binance
    case coinbase
    case bitstamp
}

enum SubscriptionScope: String, CaseIterable, Codable {
    case visibleOnly
    case all
}

@MainActor
@Observable
final class AppSettings {
    
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let dataSource = "dataSource"
        static let quoteMode = "quoteMode"
        static let subscriptionScope = "subscriptionScope"
        static let carouselInterval = "carouselInterval"
        static let verticalScrollSpeed = "verticalScrollSpeed"
        static let statusBarWidth = "statusBarWidth"
        static let displayMode = "displayMode"
    }
    
    var dataSource: DataSourceType {
        didSet { save(dataSource.rawValue, forKey: Keys.dataSource) }
    }
    
    var quoteMode: QuoteMode {
        didSet { save(quoteMode.rawValue, forKey: Keys.quoteMode) }
    }
    
    var subscriptionScope: SubscriptionScope {
        didSet { save(subscriptionScope.rawValue, forKey: Keys.subscriptionScope) }
    }
    
    var carouselInterval: TimeInterval {
        didSet { save(carouselInterval, forKey: Keys.carouselInterval) }
    }
    
    var verticalScrollSpeed: Double {
        didSet { save(verticalScrollSpeed, forKey: Keys.verticalScrollSpeed) }
    }
    
    var statusBarWidth: CGFloat {
        didSet { save(Double(statusBarWidth), forKey: Keys.statusBarWidth) }
    }
    
    var displayMode: DisplayMode {
        didSet { save(displayMode.rawValue, forKey: Keys.displayMode) }
    }
    
    private init() {
        dataSource = DataSourceType(rawValue: defaults.string(forKey: Keys.dataSource) ?? "") ?? .binance
        quoteMode = QuoteMode(rawValue: defaults.string(forKey: Keys.quoteMode) ?? "") ?? .usdt
        subscriptionScope = SubscriptionScope(rawValue: defaults.string(forKey: Keys.subscriptionScope) ?? "") ?? .visibleOnly
        carouselInterval = defaults.double(forKey: Keys.carouselInterval).nonZero ?? 5.0
        verticalScrollSpeed = defaults.double(forKey: Keys.verticalScrollSpeed).nonZero ?? 1.0
        statusBarWidth = CGFloat(defaults.double(forKey: Keys.statusBarWidth).nonZero ?? 180.0)
        displayMode = DisplayMode(rawValue: defaults.string(forKey: Keys.displayMode) ?? "") ?? .carousel
    }
    
    private func save(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
