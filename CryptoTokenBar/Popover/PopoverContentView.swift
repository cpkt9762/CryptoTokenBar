import SwiftUI

struct PopoverContentView: View {
    @State private var tokenStore = TokenStore.shared
    @State private var priceService = PriceService.shared
    @State private var settings = AppSettings.shared
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            TokenListView(
                tokens: tokenStore.tokens,
                prices: priceService.prices,
                sparklines: priceService.sparklines,
                onToggleVisibility: { token in
                    tokenStore.toggleVisibility(for: token)
                    refreshSubscriptions()
                },
                onMove: { source, destination in
                    tokenStore.move(from: source, to: destination)
                },
                onDelete: { offsets in
                    tokenStore.remove(at: offsets)
                    refreshSubscriptions()
                }
            )
            
            Divider()
            
            FooterView(
                onSettings: { showingSettings = true },
                onAdd: { showingAddSheet = true }
            )
        }
        .padding(.top, 8)
        .frame(width: 300, height: 400)
        .background(.ultraThinMaterial.opacity(0.7))
        .sheet(isPresented: $showingAddSheet) {
            AddTokenSheet(onAdd: { symbol in
                tokenStore.add(symbol: symbol)
                refreshSubscriptions()
            })
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
        }
    }
    
    private func refreshSubscriptions() {
        Task {
            try? await priceService.updateSubscriptions(
                tokens: tokenStore.tokens,
                quote: settings.quoteMode
            )
        }
    }
}

struct TokenListView: View {
    let tokens: [Token]
    let prices: [String: AggregatedPrice]
    let sparklines: [String: SparklineBuffer]
    let onToggleVisibility: (Token) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(tokens) { token in
                TokenRow(
                    token: token,
                    price: prices[token.symbol],
                    sparkline: sparklines[token.symbol],
                    onToggleVisibility: { onToggleVisibility(token) }
                )
            }
            .onMove(perform: onMove)
            .onDelete(perform: onDelete)
        }
        .listStyle(.plain)
    }
}

struct TokenRow: View {
    let token: Token
    let price: AggregatedPrice?
    let sparkline: SparklineBuffer?
    let onToggleVisibility: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            PopoverTokenIcon(symbol: token.symbol)
                .frame(width: 28, height: 28)
            
            Text(token.symbol)
                .font(.system(.body, design: .monospaced, weight: .medium))
                .frame(width: 50, alignment: .leading)
            
            if let price = price {
                Text(price.displayPrice)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            if let buffer = sparkline {
                SparklineView(points: buffer.getNormalizedPoints())
                    .frame(width: 50, height: 16)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FooterView: View {
    let onSettings: () -> Void
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onSettings) {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            Button(action: onAdd) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
    }
}

struct AddTokenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""
    let onAdd: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Token")
                .font(.headline)
            
            TextField("Symbol (e.g. BTC)", text: $symbol)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    addToken()
                }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Add") {
                    addToken()
                }
                .buttonStyle(.borderedProminent)
                .disabled(symbol.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 250)
    }
    
    private func addToken() {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        dismiss()
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.headline)
            
            Form {
                Picker("Data Source", selection: $settings.dataSource) {
                    ForEach(DataSourceType.allCases, id: \.self) { source in
                        Text(source.rawValue.capitalized).tag(source)
                    }
                }
                
                Picker("Quote", selection: $settings.quoteMode) {
                    ForEach(QuoteMode.allCases, id: \.self) { mode in
                        Text(mode.displayLabel).tag(mode)
                    }
                }
                
                Picker("Display Mode", selection: $settings.displayMode) {
                    Text("Carousel").tag(DisplayMode.carousel)
                    Text("Vertical Ticker").tag(DisplayMode.verticalTicker)
                }
                
                HStack {
                    Text("Status Bar Width")
                    Slider(value: $settings.statusBarWidth, in: 140...260)
                    Text("\(Int(settings.statusBarWidth))")
                        .monospacedDigit()
                }
            }
            .formStyle(.grouped)
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 350, height: 300)
    }
}

struct PopoverTokenIcon: View {
    let symbol: String
    
    var body: some View {
        AsyncImage(url: iconURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure, .empty:
                fallbackIcon
            @unknown default:
                fallbackIcon
            }
        }
    }
    
    private var iconURL: URL? {
        let lowercased = symbol.lowercased()
        return URL(string: "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/\(lowercased).png")
    }
    
    private var fallbackIcon: some View {
        ZStack {
            Circle()
                .fill(iconGradient)
            
            Text(symbol.prefix(1))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var iconGradient: LinearGradient {
        let colors: [Color] = {
            switch symbol {
            case "BTC": return [Color.orange, Color.yellow]
            case "ETH": return [Color.purple, Color.blue]
            case "SOL": return [Color.purple, Color.pink]
            case "BNB": return [Color.yellow, Color.orange]
            case "XMR": return [Color.orange, Color.red]
            default: return [Color.blue, Color.cyan]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

#Preview {
    PopoverContentView()
}
