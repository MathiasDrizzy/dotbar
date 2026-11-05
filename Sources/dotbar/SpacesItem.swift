import AppKit
import DotbarCore
import Observation
import SwiftUI

/// macOS's own desktops, read from the window server (CGSCopyManagedDisplaySpaces: the same calls the Dock and the
/// Mission Control tools use; read-only, no permission). The symbols are private, so they are looked up at run time: on
/// a macOS that lacks one the adapter answers nil and the bar shows no desktops, instead of failing to launch.
struct WindowServerDesktops: DesktopSource {
    private typealias Connection = @convention(c) () -> Int32
    private typealias CopySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?

    func read() -> [DisplayDesktops]? {
        guard let handle = dlopen(nil, RTLD_NOW),
            let main = dlsym(handle, "CGSMainConnectionID"), let copy = dlsym(handle, "CGSCopyManagedDisplaySpaces")
        else { return nil }
        let connection = unsafeBitCast(main, to: Connection.self)()
        let copySpaces = unsafeBitCast(copy, to: CopySpaces.self)
        guard let list = copySpaces(connection)?.takeRetainedValue() as? [[String: Any]] else { return nil }
        return NativeSpaces.parse(list)
    }

    /// The UUID the window server names a display by.
    static func identifier(of screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
            let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

/// The desktops of the display the bar is on: read again when the system says the desktop or the displays changed, and
/// every 30 seconds in case it does not say (a desktop added or removed in Mission Control sends nothing we know of).
/// One read is two calls into the window server; it is measured in the README.
@MainActor
@Observable
final class SpacesModel {
    private(set) var bar = SpacesBar()
    /// How many desktops would show without a cap (the fit reads it).
    private(set) var natural = 0
    /// How many slots fit beside the moon box (the fit sets it); nil: all.
    var cap: Int? {
        didSet { if cap != oldValue { redraw() } }
    }

    @ObservationIgnored private let source: DesktopSource
    @ObservationIgnored private var displays: [DisplayDesktops] = []
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var timer: Timer?

    private static let safetySeconds: TimeInterval = 30

    init(source: DesktopSource = WindowServerDesktops()) {
        self.source = source
    }

    func start() {
        refresh()
        let workspace = NSWorkspace.shared.notificationCenter
        for (center, name) in [
            (workspace, NSWorkspace.activeSpaceDidChangeNotification),
            (NotificationCenter.default, NSApplication.didChangeScreenParametersNotification),
        ] {
            observers.append((
                center,
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                }
            ))
        }
        let slow = Timer(timeInterval: Self.safetySeconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        slow.tolerance = 10
        RunLoop.main.add(slow, forMode: .common)
        timer = slow
    }

    func stop() {
        timer?.invalidate()
        for (center, token) in observers { center.removeObserver(token) }
        observers = []
    }

    /// Nothing read keeps what is drawn; an answer replaces it.
    private func refresh() {
        guard let read = source.read() else { return }
        displays = read
        redraw()
    }

    private func redraw() {
        let screen = NSScreen.screens.first.flatMap(WindowServerDesktops.identifier(of:))
        let all = NativeSpaces.bar(displays, on: screen, cap: nil)
        natural = all.pills.count
        let next = cap == nil ? all : NativeSpaces.bar(displays, on: screen, cap: cap)
        if next != bar { bar = next }
    }

    /// A click on a pill: Mission Control's Ctrl+N, posted when macOS lets the bar (the Accessibility permission). A
    /// full-screen Space has no number and a missing permission leaves the bar as it is: nothing is drawn wrong.
    func switchTo(_ pill: Pill) {
        guard !pill.active, let number = pill.number, let key = NativeSpaces.keyCode(forDesktop: number),
            CGPreflightPostEventAccess()
        else { return }
        CtrlDigit.post(key)
    }
}

/// Ctrl and a number key, a few milliseconds apart as a keyboard sends them, off the main thread.
enum CtrlDigit {
    private static let controlKey: CGKeyCode = 59
    private static let gapMicroseconds: UInt32 = 8000
    private static let queue = DispatchQueue(label: "dotbar.ctrl-digit")

    static func post(_ key: UInt16) {
        queue.async {
            let keys: [(CGKeyCode, Bool, CGEventFlags)] = [
                (controlKey, true, .maskControl), (CGKeyCode(key), true, .maskControl),
                (CGKeyCode(key), false, .maskControl), (controlKey, false, []),
            ]
            let source = CGEventSource(stateID: .hidSystemState)
            for (code, down, flags) in keys {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
                event.flags = flags
                event.post(tap: .cghidEventTap)
                usleep(gapMicroseconds)
            }
        }
    }
}

/// The pills of the display the bar is on, in one box: the active desktop is a solid block.
struct SpacesView: View {
    let model: SpacesModel

    var body: some View {
        // Each slot is 26 points plus 1 of padding on each side, side by side: SketchyBar's items in their bracket.
        HStack(spacing: 0) {
            ForEach(model.bar.pills, id: \.id) { pill in
                Text(pill.label)
                    .font(Theme.textFont)
                    .foregroundStyle(pill.active ? Theme.base : Theme.text)
                    .lineLimit(1)
                    .frame(width: Theme.slot, height: Theme.pillHeight)
                    .background(RoundedRectangle(cornerRadius: Theme.pillRadius).fill(pill.active ? Theme.mauve : .clear))
                    .padding(.horizontal, 1)
                    .contentShape(Rectangle())
                    .onTapGesture { model.switchTo(pill) }
            }
            if model.bar.hidden > 0 {
                Text("+\(model.bar.hidden)").font(Theme.textFont).foregroundStyle(Theme.overlay0).padding(.horizontal, 4)
            }
        }
        .frame(height: Theme.pillHeight)
        .background(RoundedRectangle(cornerRadius: Theme.pillRadius).fill(Theme.barColor))
    }
}
