extension BarStyle {
    /// SketchyBar's look (mac/config/sketchybar/colors.sh, Catppuccin Macchiato): the bar as it always was.
    public static let bar1 = BarStyle(
        id: "1", name: "Macchiato",
        palette: .init(
            base: 0x24273a, text: 0xcad3f5, mauve: 0xc6a0f6, blue: 0x8aadf4, surface0: 0x363a4f, surface1: 0x494d64,
            overlay0: 0x6e738d, red: 0xed8796, yellow: 0xeed49f, pink: 0xf5bde6, barColor: 0x242639, crust: 0x181926,
            appBlock: 0xa6da95, spotifyGreen: 0xa6da95, appleRest: 0xf5a97f, appleHover: 0xeed49f, appleOpen: 0xed8796),
        glyphs: .init(date: "\u{F00F0}", clock: "\u{F0954}", spotify: "\u{F1BC}", vorssaint: "\u{E22E}"))
}
