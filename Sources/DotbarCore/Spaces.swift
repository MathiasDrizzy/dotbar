import Foundation

/// One of macOS's own desktops (a Space), as the window server lists it.
public struct Desktop: Equatable, Sendable {
    public let id: Int
    /// A full-screen app's Space rather than a desktop.
    public let fullScreen: Bool
    /// The full-screen app's name, when the adapter knows it.
    public let app: String?

    public init(id: Int, fullScreen: Bool, app: String?) {
        self.id = id
        self.fullScreen = fullScreen
        self.app = app
    }
}

/// The desktops of one display, in Mission Control's order, and the one it shows now.
public struct DisplayDesktops: Equatable, Sendable {
    /// The display's UUID, or "Main" while displays share their Spaces.
    public let display: String
    public let desktops: [Desktop]
    public let active: Int

    public init(display: String, desktops: [Desktop], active: Int) {
        self.display = display
        self.desktops = desktops
        self.active = active
    }
}

/// Where the desktops come from. The live adapter reads the window server and fails soft (nil: nothing shown); a test
/// gives it fake data.
public protocol DesktopSource: Sendable {
    func read() -> [DisplayDesktops]?
}

/// A pill of the bar: one desktop.
public struct Pill: Equatable, Sendable {
    /// The desktop's Space id.
    public let id: String
    public let label: String
    public let active: Bool
    /// Its place among the desktops of its display (the N of Ctrl+N); nil for a full-screen Space.
    public let number: Int?
}

/// The pills of the display the bar is on, and how many left for lack of room ("+N").
public struct SpacesBar: Equatable, Sendable {
    public var pills: [Pill] = []
    public var hidden = 0

    public init() {}
}

public enum NativeSpaces {
    /// The glyph of a full-screen Space whose app is not known (Material Design "fullscreen").
    static let fullScreenGlyph = "\u{F0293}"
    /// The window server's own name for the shared list, and the type it gives to a full-screen Space.
    static let sharedDisplay = "Main"
    static let fullScreenType = 4

    /// The answer of CGSCopyManagedDisplaySpaces.
    public static func parse(_ displays: [[String: Any]]) -> [DisplayDesktops] {
        displays.compactMap { entry in
            guard let display = entry["Display Identifier"] as? String,
                let spaces = entry["Spaces"] as? [[String: Any]],
                let active = (entry["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int
            else { return nil }
            let desktops = spaces.compactMap { space -> Desktop? in
                guard let id = space["ManagedSpaceID"] as? Int else { return nil }
                return Desktop(id: id, fullScreen: (space["type"] as? Int) == fullScreenType, app: space["app"] as? String)
            }
            return DisplayDesktops(display: display, desktops: desktops, active: active)
        }
    }

    /// The pills for the display `display` (its UUID): its own entry, else the shared one, else (when no display is known) the first. Desktops are
    /// numbered by their place among the desktops (a full-screen Space has no number). Over `cap`, the last pills that
    /// are not active leave.
    public static func bar(_ displays: [DisplayDesktops], on display: String?, cap: Int?) -> SpacesBar {
        var bar = SpacesBar()
        let entry = displays.first { $0.display == display } ?? displays.first { $0.display == sharedDisplay } ?? (display == nil ? displays.first : nil)
        guard let entry else { return bar }
        var number = 0
        var pills = entry.desktops.map { desktop -> Pill in
            if desktop.fullScreen {
                return Pill(id: String(desktop.id), label: desktop.app ?? fullScreenGlyph, active: desktop.id == entry.active, number: nil)
            }
            number += 1
            return Pill(id: String(desktop.id), label: String(number), active: desktop.id == entry.active, number: number)
        }
        if let cap {
            while pills.count > cap, let index = pills.lastIndex(where: { !$0.active }) {
                pills.remove(at: index)
                bar.hidden += 1
            }
        }
        bar.pills = pills
        return bar
    }

    /// The key of Mission Control's "Switch to Desktop N" (Ctrl+N), on the ANSI layout's number row; nil past nine.
    public static func keyCode(forDesktop number: Int) -> UInt16? {
        let keys: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        return (1...keys.count).contains(number) ? keys[number - 1] : nil
    }
}
