import CoreGraphics

/// Keeps every box of the bar from covering its neighbour or sitting under the camera housing, as fit.sh did:
///   left  - Apple, the front app, the desktops and the moon and weather boxes share the strip left of the housing.
///           When they do not fit, the front app's name narrows first (down to `minNameWidth`), then desktops leave
///           (the pill says "+N").
///   right - the track right of the housing may only reach Vorssaint: it gets a character budget.
public enum BarFit {
    /// SketchyBar's notch_width: the gap kept around the camera housing, centered, on a screen that has one.
    public static let notchWidth: CGFloat = 224
    /// The front app name box (FrontAppItem): a longer name slides inside it.
    public static let nameWidth: CGFloat = 72
    public static let minNameWidth: CGFloat = 40
    /// A desktop slot: its 26 points plus 1 of padding on each side.
    public static let slotStep: CGFloat = 28
    /// The "+N" a capped pill shows.
    public static let spareForMore: CGFloat = 28
    public static let gap: CGFloat = 5
    /// JetBrains Mono at 12 points: 7.2 points a character.
    public static let charWidth: CGFloat = 7.2
    /// The Spotify logo and the paddings of the track's box, and the separator between title and artist.
    public static let mediaOverhead: CGFloat = 70
    public static let mediaMinChars = 8
    public static let mediaMaxChars = 35

    /// The left and right edges of the gap around the camera housing; on a screen without one there is no gap and both
    /// sides meet in the middle.
    public static func notch(screenWidth: CGFloat, hasNotch: Bool) -> (left: CGFloat, right: CGFloat) {
        let width = hasNotch ? notchWidth : 0
        return ((screenWidth - width) / 2, (screenWidth + width) / 2)
    }

    public struct Left: Equatable, Sendable {
        public let nameWidth: CGFloat
        /// How many desktop slots fit; nil: all of them.
        public let cap: Int?

        public init(nameWidth: CGFloat, cap: Int?) {
            self.nameWidth = nameWidth
            self.cap = cap
        }
    }

    /// `room` is what the name and the desktop slots may use together: the strip left of the moon box, less every box
    /// of fixed width. `natural` is how many desktops would show without a cap.
    public static func left(room: CGFloat, natural: Int) -> Left {
        guard natural > 0 else { return Left(nameWidth: max(minNameWidth, min(nameWidth, room.rounded(.down))), cap: nil) }
        let slots = CGFloat(natural) * slotStep
        guard room < nameWidth + slots else { return Left(nameWidth: nameWidth, cap: nil) }
        let name = room - slots
        if name >= minNameWidth { return Left(nameWidth: name.rounded(.down), cap: nil) }
        let cap = Int(((room - minNameWidth - spareForMore) / slotStep).rounded(.down))
        return Left(nameWidth: minNameWidth, cap: max(1, cap))
    }

    /// The room the name and the desktop slots share: from the left inset to the moon box, less the boxes of fixed
    /// width before the name (Apple, the gap, the green block and arrow) and the gap before the desktops.
    public static func leftRoom(
        notchLeft: CGFloat, weatherWidth: CGFloat, leftInset: CGFloat, fixedBeforeName: CGFloat
    ) -> CGFloat {
        let moonWidth: CGFloat = 25
        let beforeNotch: CGFloat = 3
        let moonLeft = notchLeft - beforeNotch - weatherWidth - gap - moonWidth
        return moonLeft - gap - leftInset - fixedBeforeName - gap
    }

    /// The characters the track may use, between the housing and Vorssaint.
    public static func mediaChars(notchRight: CGFloat, vorssaintLeft: CGFloat) -> Int {
        let room = vorssaintLeft - gap - notchRight - mediaOverhead
        let chars = Int((room / charWidth).rounded(.down))
        return min(mediaMaxChars, max(mediaMinChars, chars))
    }
}
