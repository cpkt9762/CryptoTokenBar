# CryptoTokenBar Development Guide

## Project Overview

macOS menu bar cryptocurrency price monitoring app built with Swift 6 and SwiftUI.

## Build Commands

```bash
# Build (Debug)
xcodebuild -project CryptoTokenBar.xcodeproj -scheme CryptoTokenBar -configuration Debug build

# Build (Release)
xcodebuild -project CryptoTokenBar.xcodeproj -scheme CryptoTokenBar -configuration Release build

# Build ScreenSaver bundle
xcodebuild -project CryptoTokenBar.xcodeproj -target CryptoTokenBarScreenSaver -configuration Release -destination 'platform=macOS' build

# Clean build
xcodebuild -project CryptoTokenBar.xcodeproj -scheme CryptoTokenBar clean
```

## Test Commands

```bash
# Run all tests
xcodebuild test -project CryptoTokenBar.xcodeproj -scheme CryptoTokenBar -destination 'platform=macOS'

# Run specific test file (by class name)
xcodebuild test -project CryptoTokenBar.xcodeproj -scheme CryptoTokenBar -destination 'platform=macOS' -only-testing:CryptoTokenBarTests/SparklineBufferTests

# Run specific test method
xcodebuild test -project CryptoTokenBar.xcodeproj -scheme CryptoTokenBar -destination 'platform=macOS' -only-testing:CryptoTokenBarTests/SparklineBufferTests/addPoints
```

## Run Application

```bash
# Terminate existing process
pkill -9 CryptoTokenBar

# Run after build (path varies by DerivedData)
open ~/Library/Developer/Xcode/DerivedData/CryptoTokenBar-*/Build/Products/Debug/CryptoTokenBar.app
```

## Code Style Guide

### Imports

Order imports alphabetically within groups:
1. `Foundation` (always first if needed)
2. Apple frameworks (`AppKit`, `SwiftUI`, `Observation`, etc.)
3. Third-party modules (if any)

```swift
import Foundation
import AppKit
import Observation
import SwiftUI
```

### File Structure

```swift
import Foundation

// MARK: - Type Definition
struct/class/enum TypeName {
    
    // MARK: - Properties (static first, then instance)
    static let shared = TypeName()
    
    private(set) var publicReadable: Type
    private var internalState: Type
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    func publicMethod() {}
    
    // MARK: - Private Methods
    private func helperMethod() {}
}
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Types | PascalCase | `PriceService`, `TokenStore` |
| Properties/Methods | camelCase | `isVisible`, `startPriceStream()` |
| Constants | camelCase | `static let defaultTokens` |
| Private enums for keys | `Keys` | `private enum Keys { static let ... }` |

### Type Patterns

**Singleton with @Observable:**
```swift
@MainActor
@Observable
final class ServiceName {
    static let shared = ServiceName()
    private init() {}
}
```

**Model structs:**
```swift
struct ModelName: Identifiable, Codable, Hashable {
    let id: UUID
    var mutableProperty: Type
    
    init(id: UUID = UUID(), ...) { ... }
}
```

**Error types:**
```swift
enum ServiceError: Error, Sendable {
    case connectionFailed
    case invalidData(String)
}
```

### SwiftUI Views

```swift
struct ViewName: View {
    // Environment/State first
    @Environment(ServiceType.self) private var service
    @State private var localState: Type
    
    // Computed properties
    private var computedValue: Type { ... }
    
    // Body
    var body: some View {
        content
    }
    
    // Subviews (private computed properties)
    private var subviewName: some View { ... }
}
```

### Concurrency

- Use `@MainActor` for UI-related classes
- Use `Task { }` for async work from sync context
- Use `async let` for parallel async calls
- Cancel tasks in `stop()` or `deinit`

```swift
private var task: Task<Void, Never>?

func start() {
    task = Task {
        for await item in stream {
            // process
        }
    }
}

func stop() {
    task?.cancel()
    task = nil
}
```

### Error Handling

- Prefer `throws` over optional returns for recoverable errors
- Use `do-catch` at call sites, not inside the throwing function
- Log errors with context for debugging

```swift
func connect() async throws {
    guard condition else {
        throw ServiceError.connectionFailed
    }
}

// Call site
do {
    try await service.connect()
} catch {
    debugLog("[Service] Connection failed: \(error)")
}
```

## Testing

Uses Swift Testing framework (`@Suite`, `@Test`, `#expect`).

```swift
import Testing
@testable import CryptoTokenBar

@Suite("FeatureName Tests")
struct FeatureNameTests {
    
    @Test("Description of what is being tested")
    func testMethodName() {
        // Arrange
        let sut = SystemUnderTest()
        
        // Act
        let result = sut.method()
        
        // Assert
        #expect(result == expectedValue)
    }
    
    @Test("Async operation completes")
    func asyncTest() async {
        let result = await asyncMethod()
        #expect(result != nil)
    }
}
```

## Project Structure

```
CryptoTokenBar/
├── App/                    # AppDelegate, main entry point
├── Models/                 # Data models (Token, MarketPair, PriceTick)
├── Services/               # Business logic (PriceService, TokenStore)
├── Providers/              # External data sources (Binance, Coinbase)
├── Settings/               # User preferences (AppSettings, Keychain)
├── Overlay/                # Desktop overlay windows
├── Popover/                # Menu bar popover UI
├── StatusBar/              # Menu bar status item
└── Views/                  # Shared SwiftUI views
```

## Adding New Files

When adding new Swift files to the project:
1. Create the file in the appropriate directory
2. Add file reference to `project.pbxproj` (or use Xcode)
3. Ensure the file is added to the correct target

## Debug Logging

```swift
debugLog("[Component] Message with context: \(variable)")
```

Logs are written to `/tmp/crypto_debug.log`.
