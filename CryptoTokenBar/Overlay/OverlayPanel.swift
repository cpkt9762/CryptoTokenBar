import AppKit

final class OverlayPanel: NSPanel {
    
    override var canBecomeKey: Bool { !ignoresMouseEvents }
    override var canBecomeMain: Bool { false }
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        
        isMovableByWindowBackground = true
        ignoresMouseEvents = true
        
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        level = .statusBar
    }
    
    func setClickThrough(_ enabled: Bool) {
        ignoresMouseEvents = enabled
    }
    
    func setTopLevelMode(_ mode: OverlayTopLevelMode) {
        switch mode {
        case .overFullscreenApps:
            level = .statusBar
        case .aboveAllWindows:
            level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        }
    }
    
    func setVisibilityScope(_ scope: OverlayVisibilityScope) {
        switch scope {
        case .desktopOnly:
            collectionBehavior = [.ignoresCycle, .stationary]
        case .allSpaces:
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        }
    }
}

enum OverlayTopLevelMode: String, CaseIterable {
    case overFullscreenApps
    case aboveAllWindows
    
    var displayName: String {
        switch self {
        case .overFullscreenApps: return "Cover Fullscreen Apps"
        case .aboveAllWindows: return "Always On Top (Screenaver Level)"
        }
    }
}

enum OverlayVisibilityScope: String, CaseIterable {
    case desktopOnly
    case allSpaces
    
    var displayName: String {
        switch self {
        case .desktopOnly: return "Desktop Only"
        case .allSpaces: return "All Spaces + Fullscreen"
        }
    }
}

enum OverlayDisplayMode: String, CaseIterable {
    case singleWindow
    case perScreen
    
    var displayName: String {
        switch self {
        case .singleWindow: return "Single Window (Drag Across Screens)"
        case .perScreen: return "One Panel Per Screen"
        }
    }
}
