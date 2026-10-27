import DotbarCore
import SwiftUI

/// The bar's look: the colors and glyphs of the bar chosen with `defaults write dev.dotfiles.dotbar bar -string <id>`
/// (read once, at launch; see `BarCatalog`). Sizes and fonts are the same for every bar.
enum Theme {
    static let style = BarCatalog.resolve(UserDefaults.standard.string(forKey: "bar"))

    static let base = Color(hex: style.palette.base)
    static let text = Color(hex: style.palette.text)
    static let mauve = Color(hex: style.palette.mauve)
    static let blue = Color(hex: style.palette.blue)
    static let surface1 = Color(hex: style.palette.surface1)
    static let overlay0 = Color(hex: style.palette.overlay0)
    static let surface0 = Color(hex: style.palette.surface0)
    static let red = Color(hex: style.palette.red)
    static let yellow = Color(hex: style.palette.yellow)
    static let pink = Color(hex: style.palette.pink)
    /// A box at rest: solid, the color the boxes show on screen.
    static let barColor = Color(hex: style.palette.barColor)

    static let pillHeight: CGFloat = 26
    static let pillRadius: CGFloat = 5
    static let pillGap: CGFloat = 5
    /// A workspace slot: 26 points (the icon width of the SketchyBar items).
    static let slot: CGFloat = 26
    /// The room a Nerd Font icon at ICON_SIZE takes.
    static let iconWidth: CGFloat = 17

    static let fontName = "JetBrainsMono Nerd Font"
    /// TEXT_SIZE and ICON_SIZE of icons.sh.
    static let textFont = Font.custom(fontName, size: 12).bold()
    static let iconFont = Font.custom(fontName, size: 15)
    /// The label font of the items by default (Medium), the clock's is the bold textFont.
    static let mediumFont = Font.custom("JetBrainsMono NF Medium", size: 12)
    /// sketchybar-app-font: app icons and ligatures like ":widget:".
    static let appIconFont = Font.custom("sketchybar-app-font", size: 15)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}
