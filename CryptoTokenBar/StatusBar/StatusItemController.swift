import AppKit
import SwiftUI

@MainActor
final class StatusItemController {
    
    static let defaultWidth: CGFloat = 180
    static let minWidth: CGFloat = 140
    static let maxWidth: CGFloat = 260
    
    private let statusItem: NSStatusItem
    private var hostingView: NSHostingView<StatusBarContentView>?
    private let popover: NSPopover
    private var contextMenu: NSMenu?
    private var eventMonitor: Any?
    
    var width: CGFloat {
        didSet {
            let clampedWidth = min(max(width, Self.minWidth), Self.maxWidth)
            statusItem.length = clampedWidth
        }
    }
    
    init(width: CGFloat = StatusItemController.defaultWidth) {
        self.width = min(max(width, Self.minWidth), Self.maxWidth)
        self.statusItem = NSStatusBar.system.statusItem(withLength: self.width)
        self.popover = NSPopover()
        
        setupPopover()
        setupHostingView()
        setupClickHandling()
    }
    
    private func setupPopover() {
        let hostingController = NSHostingController(rootView: PopoverContentView())
        hostingController.preferredContentSize = NSSize(width: 300, height: 400)
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
    }
    
    private func setupHostingView() {
        guard let button = statusItem.button else { return }
        
        let contentView = StatusBarContentView()
        let hosting = NSHostingView(rootView: contentView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hosting)
        
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: button.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        
        self.hostingView = hosting
    }
    
    private func setupClickHandling() {
        guard let button = statusItem.button else { return }
        
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }
    
    private var menuBarGap: CGFloat {
        let thickness = NSStatusBar.system.thickness
        return max(4, round(thickness * 0.25))
    }
    
    private func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startEventMonitor()
        }
    }
    
    private func showContextMenu() {
        guard let button = statusItem.button, let menu = contextMenu else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }
    
    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
            self?.stopEventMonitor()
        }
    }
    
    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    func setContextMenu(_ menu: NSMenu?) {
        self.contextMenu = menu
    }
    
    var button: NSStatusBarButton? {
        statusItem.button
    }
}
