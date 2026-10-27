// The bar steps aside when a window fills the screen. The window lists are what the window server gave with Chrome's
// full screen on a 1470 x 956 display.
import CoreGraphics
import DotbarCore

func fullScreenTests() async {
    let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
    let own: Int32 = 10
    func window(_ pid: Int32, _ layer: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> FullScreen.Window {
        FullScreen.Window(pid: pid, layer: layer, frame: CGRect(x: x, y: y, width: w, height: h))
    }
    func covers(_ windows: [FullScreen.Window]) -> Bool { FullScreen.covers(windows, screen: screen, own: own) }

    let chromeFull = [
        window(20, 0, 0, -73, 1470, 41), window(20, 0, 0, 33, 1470, 923), window(20, -1, 0, 0, 1470, 956),
    ]
    check("a window the size of the screen is full screen", covers(chromeFull))

    let tiled = [window(20, 0, 0, 40, 1470, 916), window(30, 0, -1, 32, 1472, 925)]
    check("tiled windows under the bar are not", !covers(tiled))

    check("the bar itself does not count", !covers([window(own, 25, 0, 0, 1470, 956)]))
    check("a window one point short is not", !covers([window(20, 0, 0, 0, 1469, 956)]))
    check("a window bigger than the screen is", covers([window(20, 0, -2, -2, 1474, 960)]))
    check("windows above the normal layer (menus, banners) never are", !covers([window(20, 25, 0, 0, 1470, 956)]))
    check("no windows, no full screen", !covers([]))
    check(
        "a window the size of another display is not this one's",
        !FullScreen.covers([window(20, 0, 1470, 0, 1470, 956)], screen: screen, own: own))
}
