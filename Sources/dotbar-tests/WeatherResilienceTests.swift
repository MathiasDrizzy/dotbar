// The weather box after a login: no network yet, or Location Services not (yet) allowed.
import DotbarCore

func weatherResilienceTests() async {
    // A failed read is tried again soon, with a growing wait, a few times; then the 30-minute read takes over.
    let waits = (1...WeatherRetry.maxRetries).map { WeatherRetry.delay(afterFailures: $0) }
    check("the first retry comes soon", (waits.first ?? nil).map { $0 <= 15 } ?? false)
    check("each retry waits longer", zip(waits, waits.dropFirst()).allSatisfy { ($0 ?? 0) < ($1 ?? 0) })
    check("no retry waits more than five minutes", waits.allSatisfy { ($0 ?? 1_000) <= 300 })
    check("retries are bounded", WeatherRetry.delay(afterFailures: WeatherRetry.maxRetries + 1) == nil)
    check("no failure, nothing to retry", WeatherRetry.delay(afterFailures: 0) == nil)

    // The reason the box gives when something is missing.
    check("all well: no reason", WeatherNote.reason(location: .authorized, hasPlace: true, readFailed: false) == nil)
    check("a place and a failed read: offline", WeatherNote.reason(location: .authorized, hasPlace: true, readFailed: true) != nil)
    let states: [LocationState] = [.denied, .notDetermined, .failed]
    let reasons = states.map { WeatherNote.reason(location: $0, hasPlace: false, readFailed: false) }
    check("no place: each state has a reason", reasons.allSatisfy { $0 != nil })
    check("the reasons differ", Set(reasons.compactMap { $0 }).count == states.count)
    check("denied points to the setting", (reasons[0] ?? "").contains("Location Services"))
    check("a place from the cache and a denied state: still says so", WeatherNote.reason(location: .denied, hasPlace: true, readFailed: false) != nil)
    check("a place from the cache and a failed fix: no noise", WeatherNote.reason(location: .failed, hasPlace: true, readFailed: false) == nil)

    // The box shows something when the place is unknown, not only the glyph.
    check("no place: the label says why", WeatherNote.label(location: .denied, hasPlace: false) != nil)
    check("a place: no stand-in label", WeatherNote.label(location: .denied, hasPlace: true) == nil)
    check("temperature alone without a commune", WeatherText.label(commune: nil, temperature: 14) == "14°C")
}
