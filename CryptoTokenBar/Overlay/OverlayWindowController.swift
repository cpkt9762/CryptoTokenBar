import AppKit
import SwiftUI
import Combine

@MainActor
final class OverlayTickerState: ObservableObject {
    @Published var isCollapsed: Bool = false
    @Published var currentIndex: Int = 0
    
    private var timer: Timer?
    
    var visibleLines: Int { 2 }
    
    func startTicker(tokenCount: Int, interval: TimeInterval) {
        stopTicker()
        
        let effectiveLines = min(visibleLines, tokenCount)
        guard tokenCount > effectiveLines else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentIndex = (self.currentIndex + 1) % tokenCount
            }
        }
    }
    
    func stopTicker() {
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        currentIndex = 0
        stopTicker()
    }
    
    nonisolated deinit {
        MainActor.assumeIsolated {
            timer?.invalidate()
        }
    }
}

@MainActor
final class OverlayWindowController {
    
    let panel: OverlayPanel
    let displayID: CGDirectDisplayID?
    let tickerState: OverlayTickerState
    
    private var hostingView: NSHostingView<OverlayContentView>
    private var moveObserver: NSObjectProtocol?
    private var saveWorkItem: DispatchWorkItem?
    private var tickerStateCancellable: AnyCancellable?
    
    init(displayID: CGDirectDisplayID? = nil) {
        self.displayID = displayID
        self.tickerState = OverlayTickerState()
        
        let contentView = OverlayContentView(tickerState: tickerState)
        self.hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        let initialFrame = NSRect(x: 100, y: 100, width: 360, height: 480)
        self.panel = OverlayPanel(contentRect: initialFrame)
        
        panel.contentView = hostingView
        
        restorePosition()
        setupMoveObserver()
        setupTickerStateObserver()
        updateWindowSize()
    }
    
    func updateWindowSize() {
        let fittingSize = hostingView.fittingSize
        if fittingSize.width > 0 && fittingSize.height > 0 {
            let origin = panel.frame.origin
            panel.setFrame(NSRect(origin: origin, size: fittingSize), display: true)
        }
    }
    
    func updateWindowSizeWithTopRightAnchor() {
        let oldFrame = panel.frame
        let fittingSize = hostingView.fittingSize
        
        guard fittingSize.width > 0 && fittingSize.height > 0 else { return }
        
        let newX = oldFrame.origin.x + (oldFrame.width - fittingSize.width)
        let newY = oldFrame.origin.y + (oldFrame.height - fittingSize.height)
        
        let newFrame = NSRect(x: newX, y: newY, width: fittingSize.width, height: fittingSize.height)
        panel.setFrame(newFrame, display: true, animate: true)
        
        clampToScreen()
    }
    
    func setCollapsed(_ collapsed: Bool, tokenCount: Int, interval: TimeInterval) {
        guard tickerState.isCollapsed != collapsed else { return }
        tickerState.isCollapsed = collapsed
        
        if collapsed {
            tickerState.startTicker(tokenCount: tokenCount, interval: interval)
        } else {
            tickerState.stopTicker()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.updateWindowSizeWithTopRightAnchor()
        }
    }
    
    nonisolated deinit {
        MainActor.assumeIsolated {
            if let observer = moveObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            saveWorkItem?.cancel()
            tickerStateCancellable?.cancel()
        }
    }
    
    private func setupMoveObserver() {
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleSavePosition()
            }
        }
    }
    
    private func setupTickerStateObserver() {
        tickerStateCancellable = tickerState.$isCollapsed
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateWindowSizeWithTopRightAnchor()
            }
    }
    
    private func scheduleSavePosition() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.savePosition()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    func show() {
        panel.orderFrontRegardless()
    }
    
    func hide() {
        panel.orderOut(nil)
    }
    
    var isVisible: Bool {
        panel.isVisible
    }
    
    func setClickThrough(_ enabled: Bool) {
        panel.setClickThrough(enabled)
    }
    
    func setTopLevelMode(_ mode: OverlayTopLevelMode) {
        panel.setTopLevelMode(mode)
    }
    
    func setVisibilityScope(_ scope: OverlayVisibilityScope) {
        panel.setVisibilityScope(scope)
    }
    
    func savePosition() {
        let frame = panel.frame
        let key = positionKey
        
        if let screen = panel.screen ?? NSScreen.main {
            let screenFrame = screen.frame
            let relativeX = (frame.origin.x - screenFrame.origin.x) / max(screenFrame.width - frame.width, 1)
            let relativeY = (frame.origin.y - screenFrame.origin.y) / max(screenFrame.height - frame.height, 1)
            
            var position: [String: Any] = [
                "relativeX": relativeX,
                "relativeY": relativeY,
                "width": frame.width,
                "height": frame.height
            ]
            
            if displayID == nil, let screenID = screen.displayID {
                position["screenID"] = screenID
            }
            
            UserDefaults.standard.set(position, forKey: key)
        }
    }
    
    func restorePosition() {
        let key = positionKey
        guard let position = UserDefaults.standard.dictionary(forKey: key),
              let relativeX = position["relativeX"] as? CGFloat,
              let relativeY = position["relativeY"] as? CGFloat,
              let width = position["width"] as? CGFloat,
              let height = position["height"] as? CGFloat else {
            centerOnScreen()
            return
        }
        
        var screen: NSScreen
        if displayID == nil, let savedScreenID = position["screenID"] as? UInt32 {
            screen = NSScreen.screens.first { screen in
                let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                return screenNumber?.uint32Value == savedScreenID
            } ?? NSScreen.main ?? NSScreen.screens.first!
        } else {
            screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first!
        }
        
        let screenFrame = screen.frame
        
        let x = screenFrame.origin.x + relativeX * (screenFrame.width - width)
        let y = screenFrame.origin.y + relativeY * (screenFrame.height - height)
        
        let clampedX = max(screenFrame.minX, min(x, screenFrame.maxX - width))
        let clampedY = max(screenFrame.minY, min(y, screenFrame.maxY - height))
        
        panel.setFrame(NSRect(x: clampedX, y: clampedY, width: width, height: height), display: true)
    }
    
    func centerOnScreen() {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first!
        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        
        let x = visibleFrame.midX - panelSize.width / 2
        let y = visibleFrame.midY - panelSize.height / 2
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func clampToScreen() {
        let screen = panel.screen ?? targetScreen ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        var frame = panel.frame
        
        frame.origin.x = max(screenFrame.minX, min(frame.origin.x, screenFrame.maxX - frame.width))
        frame.origin.y = max(screenFrame.minY, min(frame.origin.y, screenFrame.maxY - frame.height))
        
        panel.setFrameOrigin(frame.origin)
    }
    
    private var positionKey: String {
        if let displayID = displayID {
            return "overlay.position.\(displayID)"
        }
        return "overlay.position.single"
    }
    
    var targetScreen: NSScreen? {
        guard let displayID = displayID else { return nil }
        return NSScreen.screens.first { screen in
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return screenNumber?.uint32Value == displayID
        }
    }
}
