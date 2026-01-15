import ScreenSaver
import SwiftUI

@MainActor
final class CryptoTokenBarScreenSaverView: ScreenSaverView {
    private var hostingView: NSHostingView<ScreenSaverRootView>?
    private let priceStore = ScreenSaverPriceStore.shared
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0
        setupHostingView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0
        setupHostingView()
    }
    
    override func startAnimation() {
        super.startAnimation()
        priceStore.start()
    }
    
    override func stopAnimation() {
        priceStore.stop()
        super.stopAnimation()
    }
    
    override func animateOneFrame() {
        super.animateOneFrame()
    }
    
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        hostingView?.frame = bounds
    }
    
    private func setupHostingView() {
        let rootView = ScreenSaverRootView()
        let view = NSHostingView(rootView: rootView)
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view)
        hostingView = view
    }
}

private struct ScreenSaverRootView: View {
    @State private var store = ScreenSaverPriceStore.shared
    @State private var isVisible = false
    private let tokens = ScreenSaverToken.defaultTokens
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.06),
                        Color(red: 0.05, green: 0.03, blue: 0.15),
                        Color(red: 0.08, green: 0.04, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    tokenList
                    statusView
                }
                .padding(16)
                .frame(width: min(geo.size.width * 0.35, 380))
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.95)
                .padding(32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isVisible = true
            }
        }
    }
    
    private var tokenList: some View {
        VStack(spacing: 12) {
            let _ = store.sparklineVersion
            ForEach(tokens) { token in
                ScreenSaverTokenRow(
                    token: token,
                    price: store.prices[token.symbol],
                    sparklinePoints: store.sparklines[token.symbol]?.getNormalizedPoints() ?? []
                )
            }
        }
    }
    
    // Build timestamp for debugging version issues
    private static let buildTimestamp: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd-HHmm"
        return formatter.string(from: Date())
    }()
    
    private var statusView: some View {
        HStack {
            if let status = store.statusMessage {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Text("Build: \(Self.buildTimestamp)")
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}

private struct ScreenSaverTokenRow: View {
    let token: ScreenSaverToken
    let price: ScreenSaverPrice?
    let sparklinePoints: [Double]
    
    var body: some View {
        HStack(spacing: 16) {
            symbolBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(token.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text(token.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            SparklineView(points: sparklinePoints, changePercent: price?.changePercent)
                .frame(width: 60, height: 24)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(price?.displayPrice ?? "--")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: price?.displayPrice)
                Text(price?.displayChange ?? "--")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(changeColor)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: price?.displayChange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var symbolBadge: some View {
        ScreenSaverTokenIcon(symbol: token.symbol)
            .frame(width: 32, height: 32)
    }
    
    private var changeColor: Color {
        guard let change = price?.changePercent else { return .white.opacity(0.5) }
        return change >= 0 ? Color(red: 0, green: 1, blue: 0.53) : Color(red: 1, green: 0.42, blue: 0.42)
    }
}

private struct ScreenSaverTokenIcon: View {
    let symbol: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(iconGradient)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.3), Color.clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                )
                .shadow(color: iconShadowColor.opacity(0.5), radius: 4, x: 0, y: 2)
            
            Text(symbol.prefix(1))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
    }
    
    private var iconColors: [Color] {
        switch symbol {
        case "BTC": return [Color(red: 1, green: 0.6, blue: 0), Color(red: 1, green: 0.8, blue: 0.2)]
        case "ETH": return [Color(red: 0.4, green: 0.3, blue: 0.8), Color(red: 0.5, green: 0.5, blue: 1)]
        case "SOL": return [Color(red: 0.6, green: 0.2, blue: 0.8), Color(red: 0.2, green: 0.9, blue: 0.8)]
        case "BNB": return [Color(red: 0.95, green: 0.75, blue: 0.1), Color(red: 1, green: 0.85, blue: 0.3)]
        case "XMR": return [Color(red: 1, green: 0.4, blue: 0.2), Color(red: 1, green: 0.6, blue: 0.3)]
        case "DOGE": return [Color(red: 0.85, green: 0.7, blue: 0.3), Color(red: 1, green: 0.85, blue: 0.4)]
        case "SUI": return [Color(red: 0.2, green: 0.5, blue: 1), Color(red: 0.4, green: 0.8, blue: 1)]
        default: return [Color(red: 0.3, green: 0.5, blue: 0.9), Color(red: 0.5, green: 0.7, blue: 1)]
        }
    }
    
    private var iconGradient: LinearGradient {
        LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var iconShadowColor: Color {
        iconColors.first ?? .blue
    }
}
