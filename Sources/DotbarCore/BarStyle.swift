import Foundation

/// One look of the bar: its colors and its glyphs. Every bar lives in its own file under `Bars/` and is listed in
/// `BarCatalog`; `defaults write dev.dotfiles.dotbar bar -string <id>` picks one (the bar reads it at launch).
public struct BarStyle: Equatable, Sendable {
    public let id: String
    public let name: String
    public let palette: Palette
    public let glyphs: Glyphs

    public init(id: String, name: String, palette: Palette, glyphs: Glyphs) {
        self.id = id
        self.name = name
        self.palette = palette
        self.glyphs = glyphs
    }

    /// Colors as 0xRRGGBB.
    public struct Palette: Equatable, Sendable {
        public var base: UInt32
        public var text: UInt32
        public var mauve: UInt32
        public var blue: UInt32
        public var surface0: UInt32
        public var surface1: UInt32
        public var overlay0: UInt32
        public var red: UInt32
        public var yellow: UInt32
        public var pink: UInt32
        /// A box at rest.
        public var barColor: UInt32
        /// Under the bar's see-through parts.
        public var crust: UInt32
        /// The front app's block.
        public var appBlock: UInt32
        public var spotifyGreen: UInt32
        public var appleRest: UInt32
        public var appleHover: UInt32
        public var appleOpen: UInt32

        public init(
            base: UInt32, text: UInt32, mauve: UInt32, blue: UInt32, surface0: UInt32, surface1: UInt32, overlay0: UInt32,
            red: UInt32, yellow: UInt32, pink: UInt32, barColor: UInt32, crust: UInt32, appBlock: UInt32,
            spotifyGreen: UInt32, appleRest: UInt32, appleHover: UInt32, appleOpen: UInt32
        ) {
            self.base = base
            self.text = text
            self.mauve = mauve
            self.blue = blue
            self.surface0 = surface0
            self.surface1 = surface1
            self.overlay0 = overlay0
            self.red = red
            self.yellow = yellow
            self.pink = pink
            self.barColor = barColor
            self.crust = crust
            self.appBlock = appBlock
            self.spotifyGreen = spotifyGreen
            self.appleRest = appleRest
            self.appleHover = appleHover
            self.appleOpen = appleOpen
        }
    }

    /// The icons that have a say in a bar's look (Nerd Font code points).
    public struct Glyphs: Equatable, Sendable {
        public var date: String
        public var clock: String
        public var spotify: String
        public var vorssaint: String

        public init(date: String, clock: String, spotify: String, vorssaint: String) {
            self.date = date
            self.clock = clock
            self.spotify = spotify
            self.vorssaint = vorssaint
        }
    }
}

/// The bars there are. The first one is the bar's look before there were choices, and what an unknown choice falls back to.
public enum BarCatalog {
    public static let all: [BarStyle] = [.bar1, .bar2]

    /// The bar for `id` (any case); the first one when there is none or it is unknown.
    public static func resolve(_ id: String?) -> BarStyle {
        guard let id = id?.lowercased() else { return all[0] }
        return all.first { $0.id == id } ?? all[0]
    }
}
