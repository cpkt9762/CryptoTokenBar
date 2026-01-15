import SwiftUI

private func tokenFullName(_ symbol: String) -> String {
    switch symbol {
    case "BTC": return "Bitcoin"
    case "ETH": return "Ethereum"
    case "SOL": return "Solana"
    case "BNB": return "Binance Coin"
    case "XMR": return "Monero"
    case "XRP": return "Ripple"
    case "DOGE": return "Dogecoin"
    case "ADA": return "Cardano"
    case "DOT": return "Polkadot"
    case "AVAX": return "Avalanche"
    case "LINK": return "Chainlink"
    case "MATIC": return "Polygon"
    case "UNI": return "Uniswap"
    case "LTC": return "Litecoin"
    default: return symbol
    }
}

struct OverlayContentView: View {
    @State private var tokenStore = TokenStore.shared
    private var priceService = PriceService.shared
    @ObservedObject private var overlayManager = OverlayManager.shared
    @ObservedObject var tickerState: OverlayTickerState
    @State private var draggingTokenId: UUID?
    
    init(tickerState: OverlayTickerState? = nil) {
        self.tickerState = tickerState ?? OverlayTickerState()
    }
    
    private var scaledWidth: CGFloat { 340 * overlayManager.scale }
    private var scaledCornerRadius: CGFloat { 20 * overlayManager.scale }
    
    private var visibleTokens: [Token] {
        tokenStore.tokens.filter(\.isVisible)
    }
    
    var body: some View {
        let _ = priceService.sparklineVersion
        
        Group {
            if tickerState.isCollapsed {
                collapsedTickerView
            } else {
                expandedListView
            }
        }
        .frame(width: scaledWidth)
        .background(OverlayBackgroundView(opacity: overlayManager.opacity))
        .clipShape(RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous))
        .onChange(of: overlayManager.isInteractionEnabled) { _, enabled in
            if !enabled {
                draggingTokenId = nil
            }
        }
    }
    
    @ViewBuilder
    private var expandedListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleTokens.enumerated()), id: \.element.id) { index, token in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1 * overlayManager.scale)
                        .padding(.horizontal, 16 * overlayManager.scale)
                }
                
                OverlayTokenRow(
                    token: token,
                    price: priceService.prices[token.symbol],
                    sparkline: priceService.sparklines[token.symbol],
                    scale: overlayManager.scale,
                    isDragging: draggingTokenId == token.id,
                    isInteractionEnabled: overlayManager.isInteractionEnabled,
                    onDragStart: { draggingTokenId = token.id }
                )
                .dropDestination(for: String.self) { items, _ in
                    guard let draggedId = items.first,
                          let draggedUUID = UUID(uuidString: draggedId),
                          let sourceIndex = tokenStore.tokens.firstIndex(where: { $0.id == draggedUUID }),
                          let destIndex = tokenStore.tokens.firstIndex(where: { $0.id == token.id }) else {
                        draggingTokenId = nil
                        return true
                    }
                    
                    if sourceIndex != destIndex {
                        tokenStore.move(from: IndexSet(integer: sourceIndex), to: destIndex > sourceIndex ? destIndex + 1 : destIndex)
                    }
                    draggingTokenId = nil
                    return true
                } isTargeted: { _ in }
            }
        }
        .padding(.vertical, 8 * overlayManager.scale)
    }
    
    @ViewBuilder
    private var collapsedTickerView: some View {
        let tokens = visibleTokens
        let count = tokens.count
        let linesToShow = min(tickerState.visibleLines, count)
        
        VStack(spacing: 0) {
            ForEach(0..<linesToShow, id: \.self) { offset in
                let tokenIndex = (tickerState.currentIndex + offset) % count
                let token = tokens[tokenIndex]
                
                if offset > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1 * overlayManager.scale)
                        .padding(.horizontal, 16 * overlayManager.scale)
                }
                
                CompactTokenRow(
                    token: token,
                    price: priceService.prices[token.symbol],
                    sparkline: priceService.sparklines[token.symbol],
                    scale: overlayManager.scale
                )
            }
        }
        .padding(.vertical, 8 * overlayManager.scale)
        .animation(.easeInOut(duration: 0.3), value: tickerState.currentIndex)
    }
}



struct OverlayTokenRow: View {
    let token: Token
    let price: AggregatedPrice?
    let sparkline: SparklineBuffer?
    var scale: CGFloat = 1.0
    var isDragging: Bool = false
    var isInteractionEnabled: Bool = false
    var onDragStart: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 12 * scale) {
            DraggableTokenIcon(
                token: token,
                scale: scale,
                isInteractionEnabled: isInteractionEnabled,
                onDragStart: onDragStart
            )
            
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(token.symbol)
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(tokenFullName(token.symbol))
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            if let sparkline = sparkline {
                SparklineView(points: sparkline.getNormalizedPoints())
                    .frame(width: 60 * scale, height: 24 * scale)
            }
            
            VStack(alignment: .trailing, spacing: 2 * scale) {
                Text(price?.displayPrice ?? "--")
                    .font(.system(size: 15 * scale, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                
                if let change = price?.priceChange24h {
                    Text(formatChange(change))
                        .font(.system(size: 11 * scale, weight: .medium))
                        .foregroundColor(change >= 0 ? .green : .red)
                } else {
                    Text("--")
                        .font(.system(size: 11 * scale))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16 * scale)
        .padding(.vertical, 12 * scale)
        .opacity(isDragging ? 0.5 : 1.0)
    }
    
    private func formatChange(_ change: Decimal) -> String {
        let sign = change >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.multiplier = 1
        let value = formatter.string(from: change as NSDecimalNumber) ?? "0.00%"
        return sign + value
    }
}

struct CompactTokenRow: View {
    let token: Token
    let price: AggregatedPrice?
    let sparkline: SparklineBuffer?
    var scale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 10 * scale) {
            TokenIconView(symbol: token.symbol)
                .frame(width: 32 * scale, height: 32 * scale)
            
            Text(token.symbol)
                .font(.system(size: 14 * scale, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 50 * scale, alignment: .leading)
            
            if let sparkline = sparkline {
                SparklineView(points: sparkline.getNormalizedPoints())
                    .frame(width: 50 * scale, height: 20 * scale)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 1 * scale) {
                Text(price?.displayPrice ?? "--")
                    .font(.system(size: 13 * scale, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                
                if let change = price?.priceChange24h {
                    Text(formatChange(change))
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundColor(change >= 0 ? .green : .red)
                } else {
                    Text("--")
                        .font(.system(size: 10 * scale))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 8 * scale)
    }
    
    private func formatChange(_ change: Decimal) -> String {
        let sign = change >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.multiplier = 1
        let value = formatter.string(from: change as NSDecimalNumber) ?? "0.00%"
        return sign + value
    }
}

struct DraggableTokenIcon: View {
    let token: Token
    let scale: CGFloat
    let isInteractionEnabled: Bool
    let onDragStart: () -> Void
    
    var body: some View {
        NonDraggableWindowArea {
            TokenIconView(symbol: token.symbol)
                .frame(width: 40 * scale, height: 40 * scale)
                .overlay {
                    if isInteractionEnabled {
                        RoundedRectangle(cornerRadius: 8 * scale)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    }
                }
        }
        .frame(width: 40 * scale, height: 40 * scale)
        .draggable(token.id.uuidString) {
            TokenIconView(symbol: token.symbol)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .onAppear { onDragStart() }
        }
    }
}

// MARK: - NonDraggableWindowArea
// Prevents mouseDown on this area from triggering window drag (isMovableByWindowBackground)

struct NonDraggableWindowArea<Content: View>: NSViewRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeNSView(context: Context) -> NonDraggableHostingView<Content> {
        NonDraggableHostingView(rootView: content)
    }
    
    func updateNSView(_ nsView: NonDraggableHostingView<Content>, context: Context) {
        nsView.rootView = content
    }
}

final class NonDraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
}

struct OverlayBackgroundView: View {
    var opacity: Double = 0.85
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.1, blue: 0.25),
                Color(red: 0.1, green: 0.08, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(opacity)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    OverlayContentView()
        .frame(width: 360, height: 400)
        .background(Color.black)
}
