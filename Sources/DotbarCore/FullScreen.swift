import CoreGraphics

/// Whether something fills the screen, so the bar stays out of its way (a video, a browser's full screen).
public enum FullScreen {
    /// A window of the window server's list.
    public struct Window: Equatable, Sendable {
        public let pid: Int32
        public let layer: Int
        public let frame: CGRect

        public init(pid: Int32, layer: Int, frame: CGRect) {
            self.pid = pid
            self.layer = layer
            self.frame = frame
        }
    }

    /// Whether a window of another process covers the whole `screen`.
    public static func covers(_ windows: [Window], screen: CGRect, own: Int32) -> Bool {
        windows.contains { $0.pid != own && $0.layer <= 0 && $0.frame.contains(screen) }
    }
}
