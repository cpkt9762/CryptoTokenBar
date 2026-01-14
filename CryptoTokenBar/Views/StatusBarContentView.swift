import SwiftUI

struct StatusBarContentView: View {
    @State private var priceService = PriceService.shared
    @State private var settings = AppSettings.shared
    @State private var currentIndex = 0
    @State private var carouselTimer: Timer?
    
    var body: some View {
        Group {
            switch settings.displayMode {
            case .carousel:
                CarouselView(
                    prices: priceService.prices,
                    sparklines: priceService.sparklines,
                    currentIndex: $currentIndex
                )
            case .verticalTicker:
                VerticalTickerView(
                    prices: priceService.prices,
                    sparklines: priceService.sparklines
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startCarouselTimer()
        }
        .onDisappear {
            carouselTimer?.invalidate()
        }
    }
    
    private func startCarouselTimer() {
        carouselTimer?.invalidate()
        let interval = settings.carouselInterval
        carouselTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [self] _ in
            Task { @MainActor in
                let count = priceService.prices.count
                guard count > 0 else { return }
                currentIndex = (currentIndex + 1) % count
            }
        }
    }
}

struct CarouselView: View {
    let prices: [String: AggregatedPrice]
    let sparklines: [String: SparklineBuffer]
    @Binding var currentIndex: Int
    
    private var sortedSymbols: [String] {
        Array(prices.keys).sorted()
    }
    
    var body: some View {
        if let symbol = sortedSymbols[safe: currentIndex],
           let price = prices[symbol] {
            HStack(spacing: 4) {
                Text(symbol)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Text(price.displayPrice)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                
                if let buffer = sparklines[symbol] {
                    SparklineView(
                        points: buffer.getNormalizedPoints(),
                        lineColor: priceColor(for: price)
                    )
                    .frame(width: 30, height: 12)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
        } else {
            Text("Loading...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
    
    private func priceColor(for price: AggregatedPrice) -> Color {
        guard let change = price.priceChange24h else { return .gray }
        if change > 0 { return .green }
        if change < 0 { return .red }
        return .gray
    }
}

struct VerticalTickerView: View {
    let prices: [String: AggregatedPrice]
    let sparklines: [String: SparklineBuffer]
    
    @State private var offset: CGFloat = 0
    @State private var currentIndex = 0
    @State private var timer: Timer?
    
    private var sortedSymbols: [String] {
        Array(prices.keys).sorted()
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(sortedSymbols, id: \.self) { symbol in
                    if let price = prices[symbol] {
                        HStack(spacing: 4) {
                            Text(symbol)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            
                            Text(price.displayPrice)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                        .frame(height: geometry.size.height)
                    }
                }
            }
            .offset(y: offset)
            .onAppear {
                startScrollAnimation(height: geometry.size.height)
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
        .clipped()
    }
    
    private func startScrollAnimation(height: CGFloat) {
        let count = sortedSymbols.count
        guard count > 1 else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [self] _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentIndex = (currentIndex + 1) % count
                    offset = -CGFloat(currentIndex) * height
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    StatusBarContentView()
        .frame(width: 180, height: 22)
        .background(.windowBackground)
}
