import AppKit
import SwiftUI

@main
struct AILimitNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("AI Limit Notch", systemImage: "sparkles") {
            Button("Settings…") { appDelegate.showSettings() }
                .keyboardShortcut(",")
            Divider()
            Button("Show Notch") { appDelegate.showNotch() }
                .keyboardShortcut("s")
            Button("Hide Notch") { appDelegate.hideNotch() }
                .keyboardShortcut("h")
            Divider()
            Button("Quit") { appDelegate.quit() }
                .keyboardShortcut("q")
        }

    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var settingsWindow: NSWindow?
    private let notchState = NotchState.shared
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var settingsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        showNotch()
        installOutsideClickMonitors()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .notchSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.panel?.refreshCompactFrameIfNeeded() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let settingsObserver { NotificationCenter.default.removeObserver(settingsObserver) }
    }

    func showNotch() {
        if panel == nil {
            let panel = NotchPanel()
            let content = NotchView(settings: .shared, state: notchState) { [weak panel] isExpanded in
                panel?.setExpanded(isExpanded)
            }
            let hostingView = NSHostingView(rootView: content)
            hostingView.sizingOptions = []
            hostingView.frame = NSRect(origin: .zero, size: NotchPanel.compactSize)
            hostingView.autoresizingMask = [.width, .height]
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor

            // A plain AppKit container prevents NSHostingView from treating itself
            // as the window's sizing authority during SwiftUI state updates.
            let container = NSView(frame: NSRect(origin: .zero, size: NotchPanel.compactSize))
            container.autoresizingMask = [.width, .height]
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.clear.cgColor
            container.addSubview(hostingView)
            panel.contentView = container
            self.panel = panel
        }

        panel?.positionAtTopCenter()
        panel?.orderFrontRegardless()
    }

    func hideNotch() {
        panel?.orderOut(nil)
    }

    func showSettings() {
        if settingsWindow == nil {
            let hostingController = NSHostingController(
                rootView: SettingsView(settings: AppSettings.shared)
            )
            let window = NSWindow(contentViewController: hostingController)
            window.title = "AI Limit Notch Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 560, height: 390))
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("AILimitNotchSettings")
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func installOutsideClickMonitors() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.collapseForOutsideClick() }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.collapseForOutsideClick()
            return event
        }
    }

    private func collapseForOutsideClick() {
        guard notchState.isExpanded, let panel else { return }
        guard !panel.frame.contains(NSEvent.mouseLocation) else { return }
        notchState.isExpanded = false
        panel.setExpanded(false)
    }
}

@MainActor
final class NotchPanel: NSPanel {
    static var compactSize: NSSize {
        let count = max(1, AppSettings.shared.miniProviders.count)
        return NSSize(width: CGFloat(18 + count * 54), height: 20)
    }
    static let expandedSize = NSSize(width: 430, height: 360)
    static let topOffset: CGFloat = 30

    private var isAnimatingFrame = false

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.compactSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // One level above screen-saver windows keeps system menu-bar items from
        // drawing over the Notch surface.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        hidesOnDeactivate = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func positionAtTopCenter() {
        guard let screen = preferredScreen() else { return }
        let size = frame.size
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height - Self.topOffset
        )
        setFrameOrigin(origin)
    }

    func setExpanded(_ expanded: Bool) {
        guard !isAnimatingFrame else { return }
        guard let screen = preferredScreen() else { return }
        isAnimatingFrame = true
        let size = expanded ? Self.expandedSize : Self.compactSize
        let target = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height - Self.topOffset,
            width: size.width,
            height: size.height
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.42
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.9, 0.25, 1)
            animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAnimatingFrame = false
                self.contentView?.needsDisplay = true
                self.contentView?.displayIfNeeded()
                self.invalidateShadow()
            }
        }
    }

    func refreshCompactFrameIfNeeded() {
        guard !NotchState.shared.isExpanded else { return }
        setFrame(targetFrame(for: Self.compactSize), display: true)
    }

    private func targetFrame(for size: NSSize) -> NSRect {
        guard let screen = preferredScreen() else { return NSRect(origin: frame.origin, size: size) }
        return NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height - Self.topOffset,
            width: size.width,
            height: size.height
        )
    }

    private func preferredScreen() -> NSScreen? {
        if let screen = screen { return screen }
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
    }
}
