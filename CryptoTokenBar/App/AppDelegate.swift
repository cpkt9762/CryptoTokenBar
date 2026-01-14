import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItemController: StatusItemController?
    private let settings = AppSettings.shared
    private let tokenStore = TokenStore.shared
    private let overlayManager = OverlayManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController()
        setupContextMenu()
        startPriceService()
        overlayManager.restoreState()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        PriceService.shared.stop()
        overlayManager.saveAllPositions()
    }
    
    private func setupContextMenu() {
        let menu = NSMenu()
        
        let tradingViewItem = NSMenuItem(title: "Open TradingView", action: #selector(openTradingView), keyEquivalent: "")
        tradingViewItem.target = self
        menu.addItem(tradingViewItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quoteMenu = NSMenu()
        let quoteItem = NSMenuItem(title: "Quote Currency", action: nil, keyEquivalent: "")
        quoteItem.submenu = quoteMenu
        
        for mode in QuoteMode.allCases {
            let item = NSMenuItem(title: mode.displayLabel, action: #selector(selectQuote(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = mode == settings.quoteMode ? .on : .off
            quoteMenu.addItem(item)
        }
        menu.addItem(quoteItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let openPanelItem = NSMenuItem(title: "Open Panel", action: #selector(openPanel), keyEquivalent: "")
        openPanelItem.target = self
        menu.addItem(openPanelItem)
        
        let overlayItem = NSMenuItem(title: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "o")
        overlayItem.target = self
        menu.addItem(overlayItem)
        
        let opacityItem = NSMenuItem()
        let opacityView = OpacitySliderView(
            value: overlayManager.opacity,
            onChange: { [weak self] (value: Double) in
                self?.overlayManager.setOpacity(value)
            }
        )
        opacityItem.view = opacityView
        menu.addItem(opacityItem)
        
        let overlaySettingsMenu = NSMenu()
        let overlaySettingsItem = NSMenuItem(title: "Overlay Settings", action: nil, keyEquivalent: "")
        overlaySettingsItem.submenu = overlaySettingsMenu
        
        for mode in OverlayDisplayMode.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = mode == overlayManager.displayMode ? .on : .off
            overlaySettingsMenu.addItem(item)
        }
        
        overlaySettingsMenu.addItem(NSMenuItem.separator())
        
        for scope in OverlayVisibilityScope.allCases {
            let item = NSMenuItem(title: scope.displayName, action: #selector(selectVisibilityScope(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scope
            item.state = scope == overlayManager.visibilityScope ? .on : .off
            overlaySettingsMenu.addItem(item)
        }
        
        overlaySettingsMenu.addItem(NSMenuItem.separator())
        
        for level in OverlayTopLevelMode.allCases {
            let item = NSMenuItem(title: level.displayName, action: #selector(selectTopLevelMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = level
            item.state = level == overlayManager.topLevelMode ? .on : .off
            overlaySettingsMenu.addItem(item)
        }
        
        menu.addItem(overlaySettingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItemController?.setContextMenu(menu)
    }
    
    private func startPriceService() {
        Task {
            do {
                try await PriceService.shared.start(
                    tokens: tokenStore.tokens,
                    settings: settings
                )
            } catch {
                print("Failed to start price service: \(error)")
            }
        }
    }
    
    @objc private func openTradingView() {
        guard let firstVisible = tokenStore.visibleTokens.first else {
            openTradingViewFallback()
            return
        }
        
        let quote: String
        switch settings.quoteMode {
        case .usdt, .usdApprox: quote = "USDT"
        case .usdc: quote = "USDC"
        }
        
        let pair = MarketPair(base: firstVisible.symbol, quote: quote, source: settings.dataSource)
        
        if let tvSymbol = pair.tradingViewSymbol(),
           let url = URL(string: "https://www.tradingview.com/chart/?symbol=\(tvSymbol)") {
            NSWorkspace.shared.open(url)
        } else if let exchangeURL = pair.exchangeURL() {
            NSWorkspace.shared.open(exchangeURL)
        } else {
            openTradingViewFallback()
        }
    }
    
    private func openTradingViewFallback() {
        if let url = URL(string: "https://www.tradingview.com/chart/?symbol=BINANCE:BTCUSDT") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func selectQuote(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? QuoteMode,
              let menu = sender.menu else { return }
        
        for item in menu.items {
            item.state = .off
        }
        sender.state = .on
        
        settings.quoteMode = mode
        
        Task {
            try? await PriceService.shared.updateSubscriptions(
                tokens: tokenStore.tokens,
                quote: mode
            )
        }
    }
    
    @objc private func openPanel() {
        if let button = statusItemController?.button {
            button.performClick(nil)
        }
    }
    
    @objc private func toggleOverlay() {
        overlayManager.toggle()
    }
    
    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? OverlayDisplayMode,
              let menu = sender.menu else { return }
        
        for item in menu.items where item.representedObject is OverlayDisplayMode {
            item.state = .off
        }
        sender.state = .on
        overlayManager.displayMode = mode
    }
    
    @objc private func selectVisibilityScope(_ sender: NSMenuItem) {
        guard let scope = sender.representedObject as? OverlayVisibilityScope,
              let menu = sender.menu else { return }
        
        for item in menu.items where item.representedObject is OverlayVisibilityScope {
            item.state = .off
        }
        sender.state = .on
        overlayManager.visibilityScope = scope
    }
    
    @objc private func selectTopLevelMode(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? OverlayTopLevelMode,
              let menu = sender.menu else { return }
        
        for item in menu.items where item.representedObject is OverlayTopLevelMode {
            item.state = .off
        }
        sender.state = .on
        overlayManager.topLevelMode = level
    }
}

final class OpacitySliderView: NSView {
    private let slider: NSSlider
    private let label: NSTextField
    private var onChange: ((Double) -> Void)?
    
    init(value: Double, onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        
        slider = NSSlider(value: value, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        label = NSTextField(labelWithString: "Opacity: \(Int(value * 100))%")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        
        addSubview(label)
        addSubview(slider)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            slider.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            slider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        label.stringValue = "Opacity: \(Int(value * 100))%"
        onChange?(value)
    }
}
