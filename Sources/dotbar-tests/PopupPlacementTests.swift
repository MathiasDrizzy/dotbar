// Where a popup opens: under its box, never past the screen's sides (a long menu centered under the front app's pill used to
// start left of the screen, its icons and the start of its labels cut off).
import CoreGraphics
import DotbarCore

func popupPlacementTests() async {
    let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
    let apple = CGRect(x: 23, y: 0, width: 28, height: 26)
    let pill = CGRect(x: 54, y: 0, width: 117, height: 26)
    func x(_ align: PopupPlacement.Align, _ box: CGRect, _ width: CGFloat, on screen: CGRect = screen) -> CGFloat {
        PopupPlacement.x(align: align, box: box, width: width, screen: screen)
    }

    check("the Apple popup keeps its place, 2 points before its box", x(.left, apple, 200) == 21)
    check("a short menu centers under the front app's pill", x(.center, pill, 100) == pill.midX - 50)
    // Ghostty's menu: "Make Ghostty the Default Terminal" makes the popup 282 points wide; centered under the pill it began
    // at -30.
    check("a long menu under the pill starts at the left margin", x(.center, pill, 282) == 21, "\(x(.center, pill, 282))")
    check("a box at the very edge: the popup still starts at the margin", x(.left, CGRect(x: 0, y: 0, width: 28, height: 26), 200) == 21)

    let edge = CGRect(x: 1400, y: 0, width: 60, height: 26)
    check("a popup wider than the room to the right ends at the right margin", x(.left, edge, 282) == 1470 - 21 - 282)
    check("...and so does a centered one", x(.center, edge, 282) == 1470 - 21 - 282)
    check("a popup wider than the screen starts at the left margin", x(.center, pill, 2_000) == 21)

    // A second screen to the right of the main one, and one to its left.
    let right = CGRect(x: 1470, y: 0, width: 1920, height: 1080)
    check(
        "on a screen to the right: the margin is from that screen's edge",
        x(.center, CGRect(x: 1500, y: 0, width: 100, height: 26), 282, on: right) == 1470 + 21)
    check("...and a popup that fits stays put", x(.center, CGRect(x: 2000, y: 0, width: 100, height: 26), 200, on: right) == 1950)
    let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
    check("on a screen to the left (negative x) it is clamped to it", x(.left, CGRect(x: -1919, y: 0, width: 50, height: 26), 200, on: left) == -1920 + 21)
    check("...at its right side too", x(.left, CGRect(x: -40, y: 0, width: 30, height: 26), 200, on: left) == -21 - 200)
}
