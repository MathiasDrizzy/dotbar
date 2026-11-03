import CoreGraphics

/// Where a popup's left edge goes, so it never leaves its screen.
public enum PopupPlacement {
    public enum Align: Sendable {
        case left
        case center
    }

    /// The room kept between a popup and the screen's sides: where the Apple popup sits (the Apple box's left edge, 23, less
    /// the 2 points SketchyBar's popup.align=left put it before the box).
    public static let margin: CGFloat = 21
    /// SketchyBar's popup.align=left put the popup at the item's left padding.
    public static let leftPadding: CGFloat = 2

    /// The popup's left edge (in screen coordinates) under `box`: its left edge for `.left`, centered for `.center`, then
    /// moved inside `screen`. A popup wider than the room stays at the left margin.
    public static func x(align: Align, box: CGRect, width: CGFloat, screen: CGRect) -> CGFloat {
        let wanted = align == .left ? box.minX - leftPadding : box.midX - width / 2
        let lowest = screen.minX + margin
        let highest = screen.maxX - margin - width
        return max(lowest, min(wanted, highest))
    }
}
