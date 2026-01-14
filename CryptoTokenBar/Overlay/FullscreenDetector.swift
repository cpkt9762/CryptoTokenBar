import AppKit
import Combine

@MainActor
final class FullscreenDetector: ObservableObject {
    
    private static func getDisplayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
    
    static let shared = FullscreenDetector()
    
    @Published private(set) var fullscreenDisplayIDs: Set<CGDirectDisplayID> = []
    
    private var pollTimer: Timer?
    private var appActivationObserver: NSObjectProtocol?
    private var spaceChangeObserver: NSObjectProtocol?
    
    private init() {}
    
    func startMonitoring() {
        stopMonitoring()
        
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateFullscreenState()
            }
        }
        
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateFullscreenState()
            }
        }
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFullscreenState()
            }
        }
        
        updateFullscreenState()
    }
    
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceChangeObserver = nil
        }
        
        fullscreenDisplayIDs = []
    }
    
    func isFullscreen(displayID: CGDirectDisplayID) -> Bool {
        fullscreenDisplayIDs.contains(displayID)
    }
    
    func isFullscreen(for screen: NSScreen) -> Bool {
        guard let displayID = Self.getDisplayID(for: screen) else { return false }
        return isFullscreen(displayID: displayID)
    }
    
    private func updateFullscreenState() {
        var newFullscreenIDs = Set<CGDirectDisplayID>()
        
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            if fullscreenDisplayIDs != newFullscreenIDs {
                fullscreenDisplayIDs = newFullscreenIDs
            }
            return
        }
        
        let frontPID = frontApp.processIdentifier
        let myPID = ProcessInfo.processInfo.processIdentifier
        
        if frontPID == myPID {
            return
        }
        
        let windowListOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(windowListOptions, kCGNullWindowID) as? [[String: Any]] else {
            if fullscreenDisplayIDs != newFullscreenIDs {
                fullscreenDisplayIDs = newFullscreenIDs
            }
            return
        }
        
        for screen in NSScreen.screens {
            guard let displayID = Self.getDisplayID(for: screen) else { continue }
            
            let screenBounds = CGDisplayBounds(displayID)
            
            for windowInfo in windowInfoList {
                guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                      ownerPID == frontPID,
                      let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                      let windowLayer = windowInfo[kCGWindowLayer as String] as? Int,
                      windowLayer == 0 else {
                    continue
                }
                
                let windowBounds = CGRect(
                    x: boundsDict["X"] ?? 0,
                    y: boundsDict["Y"] ?? 0,
                    width: boundsDict["Width"] ?? 0,
                    height: boundsDict["Height"] ?? 0
                )
                
                if isWindowFullscreen(windowBounds: windowBounds, screenBounds: screenBounds) {
                    newFullscreenIDs.insert(displayID)
                    break
                }
            }
        }
        
        if fullscreenDisplayIDs != newFullscreenIDs {
            fullscreenDisplayIDs = newFullscreenIDs
        }
    }
    
    private func isWindowFullscreen(windowBounds: CGRect, screenBounds: CGRect) -> Bool {
        let tolerance: CGFloat = 10
        
        let widthMatch = abs(windowBounds.width - screenBounds.width) <= tolerance
        let heightMatch = abs(windowBounds.height - screenBounds.height) <= tolerance
        let xMatch = abs(windowBounds.origin.x - screenBounds.origin.x) <= tolerance
        let yMatch = abs(windowBounds.origin.y - screenBounds.origin.y) <= tolerance
        
        return widthMatch && heightMatch && xMatch && yMatch
    }
    
    nonisolated deinit {
        MainActor.assumeIsolated {
            pollTimer?.invalidate()
            if let observer = appActivationObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
            if let observer = spaceChangeObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
        }
    }
}
