extension BarStyle {
    /// A second look to switch to: Catppuccin Frappé, same glyphs. Copy this file to start another bar, then list it in
    /// `BarCatalog.all`.
    public static let bar2 = BarStyle(
        id: "2", name: "Frappé",
        palette: .init(
            base: 0x303446, text: 0xc6d0f5, mauve: 0xca9ee6, blue: 0x8caaee, surface0: 0x414559, surface1: 0x51576d,
            overlay0: 0x737994, red: 0xe78284, yellow: 0xe5c890, pink: 0xf4b8e4, barColor: 0x2c2f40, crust: 0x232634,
            appBlock: 0xa6d189, spotifyGreen: 0xa6d189, appleRest: 0xef9f76, appleHover: 0xe5c890, appleOpen: 0xe78284),
        glyphs: .init(date: "\u{F00F0}", clock: "\u{F0954}", spotify: "\u{F1BC}", vorssaint: "\u{E22E}"))
}
