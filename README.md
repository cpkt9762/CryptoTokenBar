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
- **Screen Saver** - Crypto prices displayed on lock screen (top-left corner)
- **Real-time Updates** - Live prices via Binance Futures WebSocket
- **Sparkline Charts** - Smooth Bezier curve visualization with gradient colors
- **Multi-Screen Support** - Independent overlay per display
- **Fullscreen Aware** - Auto-collapse overlay in fullscreen apps
- **FX Conversion** - USDT/USDC rates via Coinbase

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘ O` | Toggle desktop overlay |
| `⌘ Q` | Quit application |
| `⌥ Option` | Show/hide overlay (hold) |

## Mouse Controls

| Action | Effect |
|--------|--------|
| **Drag window** | Move overlay position |
| **Scroll wheel** | Zoom overlay (0.6x - 1.5x) |
| **Drag token icon** | Reorder tokens in list |

## Requirements

- macOS 15.0+
- Xcode 16.0+
- Swift 6

## Installation

Download the latest DMG from [Releases](https://github.com/cpkt9762/CryptoTokenBar/releases).

## Screen Saver

The screen saver shows live crypto prices on your lock screen.

### Build & Install

```bash
# Build the screensaver
xcodebuild -target CryptoSaver -configuration Release build

# Install to user Screen Savers folder
cp -R build/Release/CryptoSaver.saver ~/Library/Screen\ Savers/

# Open to preview/configure
open ~/Library/Screen\ Savers/CryptoSaver.saver
```

Then go to **System Settings → Screen Saver** and select **CryptoSaver**.

> **Note**: Build version auto-increments on each build to ensure the system loads the latest version.

## Build

```bash
# Main app
xcodebuild -scheme CryptoTokenBar -configuration Release build

# Screen saver only
xcodebuild -target CryptoSaver -configuration Release build
```

## License

MIT
