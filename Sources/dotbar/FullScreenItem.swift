// The bar steps aside while a window fills the screen (a video, a browser's full screen): it sits above every window
// and every Space, so it was drawn over the picture.
import AppKit
import ApplicationServices
import DotbarCore

/// Tells when a window fills the main screen. Events only, no timer: a Space change, another app in front, and the front
/// app's windows resizing (a browser's full screen is the same window made larger, with no Space change).
@MainActor
final class FullScreenWatch {
    /// Called when the answer changes, with whether a window fills the screen now.
    var onChange: ((Bool) -> Void)?
    private(set) var active = false

    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var axObserver: AXObserver?
    private var axPid: pid_t = 0
    private var pending: DispatchWorkItem?
    private static let settleSeconds = 0.15
    /// A Space change finishes animating a moment after its notification.
    private static let spaceSeconds = 1.0
    private static let notifications = [
        kAXFocusedWindowChangedNotification, kAXWindowResizedNotification, kAXWindowMovedNotification,
        kAXWindowCreatedNotification,
    ]

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { [weak self] in
            self?.checkSoon()
            self?.checkSoon(after: Self.spaceSeconds)
        }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] in
            self?.watchFrontApp()
            self?.checkSoon()
        }
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { [weak self] in
            self?.checkSoon()
        }
        watchFrontApp()
        check()
    }

    func stop() {
        observers.forEach { center, token in center.removeObserver(token) }
        observers = []
        pending?.cancel()
        unwatch()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping @MainActor () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        observers.append((center, token))
    }

    /// The last request wins: a burst of resize events is one check.
    func checkSoon(after seconds: TimeInterval = FullScreenWatch.settleSeconds) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.check() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func check() {
        guard let screen = NSScreen.screens.first else { return }
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        let windows = (list as? [[String: Any]] ?? []).compactMap { info -> FullScreen.Window? in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                let layer = info[kCGWindowLayer as String] as? Int,
                let bounds = info[kCGWindowBounds as String] as? [String: CGFloat]
            else { return nil }
            let frame = CGRect(
                x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            return FullScreen.Window(pid: pid, layer: layer, frame: frame)
        }
        let now = FullScreen.covers(windows, screen: screen.frame, own: ProcessInfo.processInfo.processIdentifier)
        guard now != active else { return }
        active = now
        onChange?(now)
    }

    /// Listens to the windows of the app in front (needs Accessibility, which the bar already asks for; without it the
    /// Space and activation events still work).
    private func watchFrontApp() {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier, pid != axPid else { return }
        unwatch()
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let watch = Unmanaged<FullScreenWatch>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async { MainActor.assumeIsolated { watch.checkSoon() } }
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let observer = created else { return }
        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.notifications {
            AXObserverAddNotification(observer, app, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        axObserver = observer
        axPid = pid
    }

    private func unwatch() {
        if let axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
        }
        axObserver = nil
        axPid = 0
    }
}
