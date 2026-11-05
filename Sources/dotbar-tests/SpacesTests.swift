// macOS's own desktops (Spaces), per display, as the bar draws them.
import DotbarCore

private func desktop(_ id: Int, fullScreen: Bool = false, app: String? = nil) -> Desktop {
    Desktop(id: id, fullScreen: fullScreen, app: app)
}

private func raw(display: String, current: Int, spaces: [(Int, Int)]) -> [String: Any] {
    [
        "Display Identifier": display,
        "Current Space": ["ManagedSpaceID": current, "type": 0],
        "Spaces": spaces.map { ["ManagedSpaceID": $0.0, "type": $0.1] },
    ]
}

func spacesTests() async {
    let mac = "DISPLAY-MAC"
    let monitor = "DISPLAY-MONITOR"

    // The window server's answer, as CGSCopyManagedDisplaySpaces gives it.
    let parsed = NativeSpaces.parse([
        raw(display: mac, current: 5, spaces: [(4, 0), (5, 0), (9, 4)]),
        raw(display: monitor, current: 7, spaces: [(7, 0)]),
    ])
    check("parse: one entry per display", parsed.map(\.display) == [mac, monitor])
    check("parse: the desktops in order", parsed[0].desktops.map(\.id) == [4, 5, 9])
    check("parse: a type 4 space is a full-screen one", parsed[0].desktops.map(\.fullScreen) == [false, false, true])
    check("parse: the active desktop", parsed[0].active == 5 && parsed[1].active == 7)
    check("parse: garbage gives nothing", NativeSpaces.parse([["nothing": 1]]).isEmpty)

    // Per display: the bar draws the desktops of the display it is on.
    let two = [
        DisplayDesktops(display: mac, desktops: [desktop(4), desktop(5), desktop(6)], active: 5),
        DisplayDesktops(display: monitor, desktops: [desktop(7), desktop(8)], active: 7),
    ]
    let onMac = NativeSpaces.bar(two, on: mac, cap: nil)
    check("the Mac's bar shows the Mac's desktops", onMac.pills.map(\.label) == ["1", "2", "3"])
    check("the active desktop is marked", onMac.pills.map(\.active) == [false, true, false])
    check("the monitor's bar shows the monitor's desktops", NativeSpaces.bar(two, on: monitor, cap: nil).pills.map(\.label) == ["1", "2"])
    check("a desktop's shortcut number is its place on its display", onMac.pills.map(\.number) == [1, 2, 3])

    // One display unplugged and plugged again: the Mac's bar does not change.
    let alone = [two[0]]
    check("the monitor unplugged: the Mac's desktops stay", NativeSpaces.bar(alone, on: mac, cap: nil) == onMac)
    check("plugged again: the same", NativeSpaces.bar(two, on: mac, cap: nil) == onMac)
    check("a display that is not there: no desktops", NativeSpaces.bar(alone, on: monitor, cap: nil).pills.isEmpty)

    // Displays share their spaces (the system setting is off): one entry, named Main, for every bar.
    let shared = [DisplayDesktops(display: "Main", desktops: [desktop(4), desktop(5)], active: 4)]
    check("shared spaces: any display uses Main", NativeSpaces.bar(shared, on: mac, cap: nil).pills.map(\.label) == ["1", "2"])
    check("no display known: the first one", NativeSpaces.bar(two, on: nil, cap: nil) == onMac)

    // Desktops added, removed, reordered, and the active one changing.
    let added = [DisplayDesktops(display: mac, desktops: [desktop(4), desktop(5), desktop(6), desktop(10)], active: 5)]
    check("a desktop added: one more pill", NativeSpaces.bar(added, on: mac, cap: nil).pills.count == 4)
    let removed = [DisplayDesktops(display: mac, desktops: [desktop(4), desktop(6)], active: 6)]
    let afterRemoval = NativeSpaces.bar(removed, on: mac, cap: nil)
    check("a desktop removed: numbers close the gap", afterRemoval.pills.map(\.label) == ["1", "2"] && afterRemoval.pills[1].active)
    let reordered = [DisplayDesktops(display: mac, desktops: [desktop(6), desktop(4), desktop(5)], active: 5)]
    let afterReorder = NativeSpaces.bar(reordered, on: mac, cap: nil)
    check("reordered: the active one follows its place", afterReorder.pills.map(\.active) == [false, false, true])
    check("the pill keeps its desktop's id", afterReorder.pills.map(\.id) == ["6", "4", "5"])
    let moved = [DisplayDesktops(display: mac, desktops: [desktop(4), desktop(5), desktop(6)], active: 6)]
    check("the active desktop changing moves the mark", NativeSpaces.bar(moved, on: mac, cap: nil).pills.map(\.active) == [false, false, true])

    // A full-screen app's space: drawn like a desktop, with its app's name or a glyph, and not numbered.
    let full = [
        DisplayDesktops(
            display: mac, desktops: [desktop(4), desktop(5), desktop(9, fullScreen: true, app: "Safari"), desktop(6)], active: 9)
    ]
    let withFull = NativeSpaces.bar(full, on: mac, cap: nil)
    check("full screen: it is a pill", withFull.pills.count == 4)
    check("full screen: labeled with the app", withFull.pills[2].label == "Safari")
    check("full screen: a glyph without a name", NativeSpaces.bar([DisplayDesktops(display: mac, desktops: [desktop(9, fullScreen: true)], active: 9)], on: mac, cap: nil).pills[0].label == "\u{F0293}")
    check("full screen: not numbered, and the desktops after it keep counting", withFull.pills.map(\.number) == [1, 2, nil, 3])
    check("full screen: can be the active one", withFull.pills[2].active)

    // Too many for the room: the last desktops that are not active leave, counted.
    let many = [DisplayDesktops(display: mac, desktops: (1...6).map { desktop($0) }, active: 6)]
    let capped = NativeSpaces.bar(many, on: mac, cap: 4)
    check("capped: the active one stays", capped.pills.contains { $0.active })
    check("capped: the rest is counted", capped.pills.count == 4 && capped.hidden == 2)
    check("capped: the first ones stay", capped.pills.prefix(3).map(\.label) == ["1", "2", "3"])

    // Switching: Mission Control's Ctrl+N for the first nine desktops.
    check("shortcut keys: 1 is the key code 18", NativeSpaces.keyCode(forDesktop: 1) == 18)
    check("shortcut keys: 9 is the key code 25", NativeSpaces.keyCode(forDesktop: 9) == 25)
    check("shortcut keys: no key past nine", NativeSpaces.keyCode(forDesktop: 10) == nil)
    check("shortcut keys: none for zero", NativeSpaces.keyCode(forDesktop: 0) == nil)

    // The adapter fails soft: nothing read means no pills, and what was drawn stays.
    check("no answer from the window server: no desktops", NativeSpaces.bar([], on: mac, cap: nil).pills.isEmpty)
}
