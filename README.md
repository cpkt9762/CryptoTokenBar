# CryptoTokenBar

A macOS menu bar app for real-time cryptocurrency price tracking.

<p align="center">
  <img src="screenshots/popover.png" width="320" alt="Menu Bar Popover">
  &nbsp;&nbsp;&nbsp;
  <img src="screenshots/overlay.png" width="280" alt="Desktop Overlay">
</p>

## Features

- **Menu Bar Display** - Price carousel with sparkline charts
- **Desktop Overlay** - Draggable, resizable floating window
- **Real-time Updates** - Live prices via Binance Futures WebSocket
- **Sparkline Charts** - Visual price history for each token
- **Multi-Screen Support** - Independent overlay per display
- **Fullscreen Aware** - Auto-collapse overlay in fullscreen apps
- **FX Conversion** - USDT/USDC rates via Coinbase

## Requirements

- macOS 15.0+
- Xcode 16.0+
- Swift 6

## Build

```bash
xcodebuild -project CryptoTokenBar.xcodeproj -scheme CryptoTokenBar -configuration Release build
```

## License

MIT
