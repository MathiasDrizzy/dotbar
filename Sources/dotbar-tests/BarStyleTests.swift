// The bars the user can choose between: `defaults write dev.dotfiles.dotbar bar -string <id>`.
import DotbarCore

func barStyleTests() async {
    let all = BarCatalog.all
    check("there is more than one bar to choose from", all.count >= 2)
    check("every bar has its own id", Set(all.map(\.id)).count == all.count)
    check("every bar has a name", all.allSatisfy { !$0.name.isEmpty })

    check("no choice made: the first bar", BarCatalog.resolve(nil) == all[0])
    check("a choice that is no bar: the first bar", BarCatalog.resolve("no-such-bar") == all[0])
    check("each id finds its own bar", all.allSatisfy { BarCatalog.resolve($0.id) == $0 })
    check("the id is not case sensitive", BarCatalog.resolve(all[1].id.uppercased()) == all[1])

    // Bar 1 is the look the bar always had (SketchyBar's Catppuccin Macchiato): choosing nothing must not change it.
    let first = BarCatalog.resolve(nil)
    check("bar 1 keeps the base color", first.palette.base == 0x24273a)
    check("bar 1 keeps the box color", first.palette.barColor == 0x242639)
    check("bar 1 keeps the apple's colors", first.palette.appleRest == 0xf5a97f && first.palette.appleOpen == 0xed8796)
    check("bar 1 keeps the clock and date glyphs", first.glyphs.clock == "\u{F0954}" && first.glyphs.date == "\u{F00F0}")
    check("bar 1 keeps the Spotify and Vorssaint glyphs", first.glyphs.spotify == "\u{F1BC}" && first.glyphs.vorssaint == "\u{E22E}")

    check("another bar looks different", all[1].palette != first.palette)
}
