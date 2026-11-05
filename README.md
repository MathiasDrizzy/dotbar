# dotbar

A native macOS menu-bar replacement written in Swift (AppKit, no third-party dependencies), built to sit on top of the system menu bar: macOS's own desktops (Spaces), the front app, weather, battery, clock, Control Center and more, with a very small CPU and memory footprint.

```sh
scripts/bundle.sh ~/Applications     # builds dotbar.app (signed with a local certificate when one exists)
swift run dotbar-tests               # the tests
```

Started at login by a launch agent that [dotfiles](https://github.com/MathiasDrizzy/dotfiles) installs. First run asks for Location (the weather box) and Accessibility (menus, Control Center) in System Settings.

`DotbarCore` holds the pure logic (formatting, state machines, parsing) with the tests; `dotbar` is the AppKit shell.

## Desktops

The first box shows macOS's own desktops (Spaces) of the display the bar is on, read from the window server with `CGSCopyManagedDisplaySpaces` (a private call, looked up at run time and read-only: no SIP change, no Screen Recording; where it is missing the box is simply empty). It follows `NSWorkspace.activeSpaceDidChangeNotification` and the display-change notification, plus one read every 30 seconds in case a desktop was added or removed in Mission Control without a notification. A read measured about 50 µs, so that timer costs nothing a meter can see. A full-screen app's Space is a pill too, with the app's name or a glyph.

Clicking a desktop posts Mission Control's shortcut Ctrl+N (N is the desktop's place on its display, 1 to 9). It needs the Accessibility permission and the shortcut turned on in System Settings > Keyboard > Keyboard Shortcuts > Mission Control; without either, the click does nothing. With "Displays have separate Spaces" on, each display has its own desktops; the bar shows the ones of the display it is on.

## Bars

Each look of the bar (its colors and glyphs) is a `BarStyle` in its own file under `Sources/DotbarCore/Bars/`, listed in `BarCatalog.all`. Bar 1 is the original look, bar 2 a second one to switch to.

```sh
defaults write dev.dotfiles.dotbar bar -string 2   # choose a bar (read at launch)
defaults delete dev.dotfiles.dotbar bar            # back to bar 1
launchctl kickstart -k gui/$(id -u)/dev.dotfiles.dotbar
```

To make another bar, copy `Bar2.swift`, change its id, name, colors and glyphs, and add it to `BarCatalog.all`.
