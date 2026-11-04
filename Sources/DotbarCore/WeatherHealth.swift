import Foundation

/// What Location Services says about this app, reduced to what the weather box needs to know.
public enum LocationState: Equatable, Sendable {
    case authorized
    case denied
    case notDetermined
    /// Allowed, but the last fix attempt failed (no Wi-Fi around, Location Services still starting after a login).
    case failed
}

/// When a failed temperature read is tried again: soon, with a growing wait, a few times. The 30-minute read and the
/// wake and move events then take over, so a login without a network yet does not leave the box empty for half an hour.
public enum WeatherRetry {
    public static let maxRetries = 6
    static let first: TimeInterval = 10
    static let longest: TimeInterval = 300

    /// Seconds to wait after the nth consecutive failure; nil when there was none or the retries are used up.
    public static func delay(afterFailures failures: Int) -> TimeInterval? {
        guard failures >= 1, failures <= maxRetries else { return nil }
        return min(first * pow(2, Double(failures - 1)), longest)
    }
}

/// Why the weather box is incomplete, in words the user can act on (the box's tooltip and, with no place at all, its text).
public enum WeatherNote {
    /// The tooltip: nil when nothing is missing.
    public static func reason(location: LocationState, hasPlace: Bool, readFailed: Bool) -> String? {
        switch location {
        case .denied:
            return "Location Services is off for dotbar: allow it in System Settings > Privacy & Security > Location Services."
        case .notDetermined:
            return hasPlace ? nil : "Waiting for the Location Services permission."
        case .failed:
            return hasPlace ? (readFailed ? offline : nil) : "No location fix yet; trying again."
        case .authorized:
            return hasPlace && readFailed ? offline : nil
        }
    }

    /// The box's text when there is no place to read the temperature for (so it is never only a glyph).
    public static func label(location: LocationState, hasPlace: Bool) -> String? {
        guard !hasPlace else { return nil }
        switch location {
        case .denied: return "Location off"
        case .notDetermined: return "Location?"
        case .failed, .authorized: return "Locating…"
        }
    }

    private static let offline = "Could not read the temperature; trying again."
}
