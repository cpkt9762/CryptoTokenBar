import AppKit
import Combine

private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        if self <= 0 { return defaultValue }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

@MainActor
final class OverlayManager: ObservableObject {
    
    static let shared = OverlayManager()
    
    private var singleWindowController: OverlayWindowController?
    private var perScreenControllers: [CGDirectDisplayID: OverlayWindowController] = [:]
    
    nonisolated(unsafe) private var globalMonitor: Any?
    nonisolated(unsafe) private var localMonitor: Any?
    nonisolated(unsafe) private var scrollMonitor: Any?
    nonisolated(unsafe) private var screenObserver: NSObjectProtocol?
    
    private var fullscreenDetector = FullscreenDetector.shared
    private var fullscreenCancellable: AnyCancellable?
    private var settings = AppSettings.shared
    
    private(set) var isVisible = false
    private(set) var isInteractionEnabled = false
    
    var displayMode: OverlayDisplayMode {
        get { OverlayDisplayMode(rawValue: UserDefaults.standard.string(forKey: "overlay.displayMode") ?? "") ?? .singleWindow }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "overlay.displayMode")
            rebuildWindows()
        }
    }
    
    var visibilityScope: OverlayVisibilityScope {
        get { OverlayVisibilityScope(rawValue: UserDefaults.standard.string(forKey: "overlay.visibilityScope") ?? "") ?? .allSpaces }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "overlay.visibilityScope")
            applyVisibilityScope(newValue)
        }
    }
    
    var topLevelMode: OverlayTopLevelMode {
        get { OverlayTopLevelMode(rawValue: UserDefaults.standard.string(forKey: "overlay.topLevelMode") ?? "") ?? .overFullscreenApps }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "overlay.topLevelMode")
            applyTopLevelMode(newValue)
        }
    }
    
    var fullscreenBehavior: OverlayFullscreenBehavior {
        get { OverlayFullscreenBehavior(rawValue: UserDefaults.standard.string(forKey: "overlay.fullscreenBehavior") ?? "") ?? .hide }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "overlay.fullscreenBehavior")
            updateCollapsedStates()
        }
    }
    
    var interactionModifiers: NSEvent.ModifierFlags {
        get {
            let raw = UserDefaults.standard.integer(forKey: "overlay.interactionModifiers")
            return raw == 0 ? .option : NSEvent.ModifierFlags(rawValue: UInt(raw))
        }
        set {
            UserDefaults.standard.set(Int(newValue.rawValue), forKey: "overlay.interactionModifiers")
        }
    }
    
    @Published var opacity: Double = UserDefaults.standard.double(forKey: "overlay.opacity").clamped(to: 0.0...1.0, default: 0.85)
    @Published var scale: CGFloat = CGFloat(UserDefaults.standard.double(forKey: "overlay.scale").clamped(to: 0.6...1.5, default: 1.0))
    
    func setOpacity(_ value: Double) {
        let clamped = value.clamped(to: 0.0...1.0, default: 0.85)
        opacity = clamped
        UserDefaults.standard.set(clamped, forKey: "overlay.opacity")
    }
    
    func adjustScale(delta: CGFloat) {
        let newScale = (scale + delta).clamped(to: 0.6...1.5)
        scale = newScale
        UserDefaults.standard.set(Double(newScale), forKey: "overlay.scale")
    }
    
    private init() {
        setupScreenObserver()
        setupFullscreenObserver()
    }
    
    private func setupFullscreenObserver() {
        fullscreenCancellable = fullscreenDetector.$fullscreenDisplayIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Set<CGDirectDisplayID>) in
                Task { @MainActor in
                    self?.updateCollapsedStates()
                }
            }
    }
    
    private func updateCollapsedStates() {
        let tokenCount = TokenStore.shared.tokens.filter(\.isVisible).count
        let interval = settings.carouselInterval
        let behavior = fullscreenBehavior
        
        if let controller = singleWindowController {
            let screen = controller.panel.screen ?? controller.targetScreen ?? NSScreen.main
            let isFullscreen = screen.flatMap { fullscreenDetector.isFullscreen(for: $0) } ?? false
            
            if behavior == .hide {
                if isFullscreen {
                    controller.panel.orderOut(nil)
                } else if isVisible {
                    controller.panel.orderFrontRegardless()
                }
                controller.setCollapsed(false, tokenCount: tokenCount, interval: interval)
            } else {
                controller.setCollapsed(isFullscreen, tokenCount: tokenCount, interval: interval)
            }
        }
        
        for (displayID, controller) in perScreenControllers {
            let isFullscreen = fullscreenDetector.isFullscreen(displayID: displayID)
            
            if behavior == .hide {
                if isFullscreen {
                    controller.panel.orderOut(nil)
                } else if isVisible {
                    controller.panel.orderFrontRegardless()
                }
                controller.setCollapsed(false, tokenCount: tokenCount, interval: interval)
            } else {
                controller.setCollapsed(isFullscreen, tokenCount: tokenCount, interval: interval)
            }
        }
    }
    
    func restoreState() {
        if UserDefaults.standard.bool(forKey: "overlay.isVisible") {
            show()
        }
    }
    
    func show() {
        guard !isVisible else { return }
        isVisible = true
        UserDefaults.standard.set(true, forKey: "overlay.isVisible")
        
        setupEventMonitors()
        fullscreenDetector.startMonitoring()
        
        switch displayMode {
        case .singleWindow:
            showSingleWindow()
        case .perScreen:
            showPerScreenWindows()
        }
        
        updateCollapsedStates()
    }
    
    func hide() {
        guard isVisible else { return }
        isVisible = false
        UserDefaults.standard.set(false, forKey: "overlay.isVisible")
        
        removeEventMonitors()
        fullscreenDetector.stopMonitoring()
        saveAllPositions()
        
        singleWindowController?.hide()
        for controller in perScreenControllers.values {
            controller.hide()
        }
    }
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    func isScreenEnabled(_ displayID: CGDirectDisplayID) -> Bool {
        let key = "overlay.screen.\(displayID).enabled"
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
    
    func setScreenEnabled(_ displayID: CGDirectDisplayID, enabled: Bool) {
        let key = "overlay.screen.\(displayID).enabled"
        UserDefaults.standard.set(enabled, forKey: key)
        
        if displayMode == .perScreen {
            rebuildWindows()
        }
    }
    
    private func showSingleWindow() {
        if singleWindowController == nil {
            singleWindowController = OverlayWindowController()
        }
        
        applySettings(to: singleWindowController!)
        singleWindowController?.show()
    }
    
    private func showPerScreenWindows() {
        let screens = NSScreen.screens
        var currentDisplayIDs = Set<CGDirectDisplayID>()
        
        for screen in screens {
            guard let displayID = screen.displayID else { continue }
            currentDisplayIDs.insert(displayID)
            
            guard isScreenEnabled(displayID) else { continue }
            
            if perScreenControllers[displayID] == nil {
                let controller = OverlayWindowController(displayID: displayID)
                perScreenControllers[displayID] = controller
            }
            
            if let controller = perScreenControllers[displayID] {
                applySettings(to: controller)
                controller.show()
            }
        }
        
        let staleIDs = Set(perScreenControllers.keys).subtracting(currentDisplayIDs)
        for displayID in staleIDs {
            perScreenControllers[displayID]?.hide()
            perScreenControllers.removeValue(forKey: displayID)
        }
    }
    
    private func rebuildWindows() {
        let wasVisible = isVisible
        
        singleWindowController?.hide()
        singleWindowController = nil
        
        for controller in perScreenControllers.values {
            controller.hide()
        }
        perScreenControllers.removeAll()
        
        if wasVisible {
            switch displayMode {
            case .singleWindow:
                showSingleWindow()
            case .perScreen:
                showPerScreenWindows()
            }
        }
    }
    
    private func applySettings(to controller: OverlayWindowController) {
        controller.setVisibilityScope(visibilityScope)
        controller.setTopLevelMode(topLevelMode)
        controller.setClickThrough(!isInteractionEnabled)
    }
    
    private func applyVisibilityScope(_ scope: OverlayVisibilityScope) {
        singleWindowController?.setVisibilityScope(scope)
        for controller in perScreenControllers.values {
            controller.setVisibilityScope(scope)
        }
    }
    
    private func applyTopLevelMode(_ mode: OverlayTopLevelMode) {
        singleWindowController?.setTopLevelMode(mode)
        for controller in perScreenControllers.values {
            controller.setTopLevelMode(mode)
        }
    }
    
    private func setInteractionEnabled(_ enabled: Bool) {
        guard isInteractionEnabled != enabled else { return }
        isInteractionEnabled = enabled
        
        singleWindowController?.setClickThrough(!enabled)
        for controller in perScreenControllers.values {
            controller.setClickThrough(!enabled)
        }
        
        if !enabled {
            saveAllPositions()
            UserDefaults.standard.set(Double(scale), forKey: "overlay.scale")
        }
    }
    
    private func setupEventMonitors() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let targetModifiers = self.interactionModifiers
            
            let isHolding = modifiers.contains(targetModifiers)
            
            Task { @MainActor in
                self.setInteractionEnabled(isHolding)
            }
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
            return event
        }
        
        let scrollHandler: (NSEvent) -> Void = { [weak self] event in
            guard let self = self, self.isInteractionEnabled else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            guard self.isMouseOverAnyOverlay(mouseLocation) else { return }
            
            let delta = event.scrollingDeltaY * 0.01
            Task { @MainActor in
                self.adjustScale(delta: CGFloat(delta))
            }
        }
        
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel, handler: scrollHandler)
        
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self, self.isInteractionEnabled else { return event }
            
            let mouseLocation = NSEvent.mouseLocation
            guard self.isMouseOverAnyOverlay(mouseLocation) else { return event }
            
            let delta = event.scrollingDeltaY * 0.01
            Task { @MainActor in
                self.adjustScale(delta: CGFloat(delta))
            }
            return event
        }
    }
    
    private func removeEventMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        
        setInteractionEnabled(false)
    }
    
    private func setupScreenObserver() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenChange()
            }
        }
    }
    
    private func handleScreenChange() {
        singleWindowController?.clampToScreen()
        
        if displayMode == .perScreen && isVisible {
            showPerScreenWindows()
        }
        
        for controller in perScreenControllers.values {
            controller.clampToScreen()
        }
    }
    
    func saveAllPositions() {
        singleWindowController?.savePosition()
        for controller in perScreenControllers.values {
            controller.savePosition()
        }
    }
    
    private nonisolated func isMouseOverAnyOverlay(_ point: NSPoint) -> Bool {
        MainActor.assumeIsolated {
            if let controller = singleWindowController, controller.isVisible {
                if controller.panel.frame.contains(point) {
                    return true
                }
            }
            for controller in perScreenControllers.values where controller.isVisible {
                if controller.panel.frame.contains(point) {
                    return true
                }
            }
            return false
        }
    }
    
    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
