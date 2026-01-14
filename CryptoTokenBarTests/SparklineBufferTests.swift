import Testing
@testable import CryptoTokenBar

@Suite("SparklineBuffer Tests")
struct SparklineBufferTests {
    
    @Test("Buffer adds points correctly")
    func addPoints() {
        let buffer = SparklineBuffer()
        
        buffer.add(price: 100)
        buffer.add(price: 105)
        buffer.add(price: 102)
        
        let points = buffer.getPoints()
        #expect(points.count == 3)
    }
    
    @Test("Normalized points are between 0 and 1")
    func normalizedPoints() {
        let buffer = SparklineBuffer()
        
        buffer.add(price: 100)
        buffer.add(price: 200)
        buffer.add(price: 150)
        
        let normalized = buffer.getNormalizedPoints()
        
        for point in normalized {
            #expect(point >= 0)
            #expect(point <= 1)
        }
    }
    
    @Test("Buffer clears correctly")
    func clearBuffer() {
        let buffer = SparklineBuffer()
        
        buffer.add(price: 100)
        buffer.add(price: 200)
        buffer.clear()
        
        #expect(buffer.getPoints().isEmpty)
    }
}
