import CoreGraphics

/// Where the bar sits on a screen. AppKit puts the origin at the bottom left of the screen, y growing upwards.
public enum BarEdge: String, Sendable {
    case top
    /// Development only: drawn at the bottom, next to SketchyBar, until dotbar replaces it.
    case bottom
}

public enum BarGeometry {
    /// The bar's height in points: SketchyBar's, so the boxes keep their size and the cover hides the same strip.
    public static let height: CGFloat = 40

    /// How tall the cover is: the native menu bar that slides down plus 2 points, never more than the bar. Taller, it hid
    /// the first points of the windows under the bar, where a focus border has its top edge.
    public static func coverHeight(menuBar: CGFloat) -> CGFloat { min(height, menuBar + 2) }

    /// The bar's frame on a screen whose full frame is `screen`: the whole width, `height` tall, at `edge`.
    public static func frame(on screen: CGRect, edge: BarEdge, height: CGFloat = BarGeometry.height) -> CGRect {
        let y = edge == .top ? screen.maxY - height : screen.minY
        return CGRect(x: screen.minX, y: y, width: screen.width, height: height)
    }

    /// The frame to put the bar back in when it is not where it should be (a Dock restart or another program moved the
    /// window); nil when it is in place, within half a point.
    public static func correction(current: CGRect, wanted: CGRect) -> CGRect? {
        let same = [
            current.minX - wanted.minX, current.minY - wanted.minY, current.width - wanted.width, current.height - wanted.height,
        ].allSatisfy { abs($0) <= 0.5 }
        return same ? nil : wanted
    }
}
