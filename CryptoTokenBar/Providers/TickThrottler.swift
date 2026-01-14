import Foundation

actor TickThrottler {
    
    private var lastEmitTime: [String: Date] = [:]
    private let minInterval: TimeInterval
    
    init(minInterval: TimeInterval = 0.1) {
        self.minInterval = minInterval
    }
    
    func shouldEmit(for symbol: String) -> Bool {
        let now = Date()
        
        if let lastTime = lastEmitTime[symbol] {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < minInterval {
                return false
            }
        }
        
        lastEmitTime[symbol] = now
        return true
    }
    
    func reset() {
        lastEmitTime.removeAll()
    }
}

actor SubscriptionDiff {
    
    private var currentSubscriptions: Set<MarketPair> = []
    
    func compute(desired: Set<MarketPair>) -> (subscribe: [MarketPair], unsubscribe: [MarketPair]) {
        let toSubscribe = desired.subtracting(currentSubscriptions)
        let toUnsubscribe = currentSubscriptions.subtracting(desired)
        
        currentSubscriptions = desired
        
        return (Array(toSubscribe), Array(toUnsubscribe))
    }
    
    func clear() {
        currentSubscriptions.removeAll()
    }
}
