import Foundation

final class SparklineBuffer: @unchecked Sendable {
    
    private let windowSeconds: TimeInterval = 60
    private let maxPoints = 60
    
    private var buffer: [(timestamp: Date, price: Decimal)] = []
    private let lock = NSLock()
    
    init() {
        buffer.reserveCapacity(maxPoints)
    }
    
    func add(price: Decimal) {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        buffer.append((timestamp: now, price: price))
        
        let cutoff = now.addingTimeInterval(-windowSeconds)
        buffer.removeAll { $0.timestamp < cutoff }
        
        if buffer.count > maxPoints {
            buffer = downsample(buffer, to: maxPoints)
        }
    }
    
    func getPoints() -> [Decimal] {
        lock.lock()
        defer { lock.unlock() }
        return buffer.map(\.price)
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
    
    private func downsample(_ data: [(timestamp: Date, price: Decimal)], to count: Int) -> [(timestamp: Date, price: Decimal)] {
        guard data.count > count else { return data }
        
        let step = Double(data.count) / Double(count)
        var result: [(timestamp: Date, price: Decimal)] = []
        result.reserveCapacity(count)
        
        for i in 0..<count {
            let index = Int(Double(i) * step)
            if index < data.count {
                result.append(data[index])
            }
        }
        
        return result
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll()
    }
}
