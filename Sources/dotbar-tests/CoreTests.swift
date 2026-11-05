// The core's checks: the bar's frame, the command runner, the stream, the status items.
import CoreGraphics
import DotbarCore
import Foundation

func coreTests() async {
    // The bar's frame.
    let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
    check(
        "the bar spans the top of the screen, 40 points tall",
        BarGeometry.frame(on: screen, edge: .top) == CGRect(x: 0, y: 916, width: 1470, height: 40))
    check(
        "in development it sits at the bottom",
        BarGeometry.frame(on: screen, edge: .bottom) == CGRect(x: 0, y: 0, width: 1470, height: 40))
    let second = CGRect(x: 1470, y: -200, width: 2560, height: 1440)
    check(
        "on another screen it follows that screen's frame",
        BarGeometry.frame(on: second, edge: .top) == CGRect(x: 1470, y: 1200, width: 2560, height: 40))

    // The cover hides the native bar that slides down, not the first points of the windows under it: a focus border
    // (dotborder) straddles its window's top edge, which the 40-point strip used to cover when the pointer went up.
    check("the cover reaches 2 points below a 32-point native bar", BarGeometry.coverHeight(menuBar: 32) == 34)
    check("...never taller than the bar", BarGeometry.coverHeight(menuBar: 60) == BarGeometry.height)
    check("...and a plain 24-point bar gets 26", BarGeometry.coverHeight(menuBar: 24) == 26)

    // The command runner.
    let runner = CommandRunner()
    let echo = await runner.run("/bin/echo", ["hello"], timeout: 2)
    check("a command's output is read", echo.stdout == "hello\n" && echo.status == 0 && !echo.timedOut, "\(echo)")

    let missing = await runner.run("/nonexistent/command", timeout: 2)
    check("a command that does not exist fails at once", missing.status == 127, "\(missing)")

    // A hung command: a duration no other process has, so the check sees only this one.
    let hang = "3000\(getpid())"
    let started = Date()
    let hung = await runner.run("/bin/sleep", [hang], timeout: 0.5)
    let took = Date().timeIntervalSince(started)
    check("a hung command is ended by its time limit", hung.timedOut && took < 2, "took \(took) s, \(hung)")
    check("...and nothing of it is left running", running("sleep \(hang)") == 0, "\(running("sleep \(hang)")) left")

    // Five callers at once under one key while the command runs: one process, one shared answer.
    let shared = CommandRunner()
    let answers = await withTaskGroup(of: CommandRunner.Output.self) { group in
        for _ in 0..<5 {
            group.addTask { await shared.run("/bin/sh", ["-c", "sleep 0.3; echo once"], timeout: 2, key: "same") }
        }
        var all: [CommandRunner.Output] = []
        for await answer in group { all.append(answer) }
        return all
    }
    let launchesWhileRunning = await shared.launchCount
    check("callers that ask while it runs share one process", launchesWhileRunning == 1, "\(launchesWhileRunning)")
    check("...and all get its answer", answers.count == 5 && answers.allSatisfy { $0.stdout == "once\n" })

    let later = await shared.run("/bin/sh", ["-c", "echo again"], timeout: 2, key: "same")
    let launchesAfter = await shared.launchCount
    check("once it finished, the key runs again", later.stdout == "again\n" && launchesAfter == 2)

    // A long-lived stream: lines arrive one by one, and it starts again when the command ends.
    final class Lines: @unchecked Sendable {
        let lock = NSLock()
        var all: [String] = []
    }
    let received = Lines()
    let stream = LineStream("/bin/sh", ["-c", "echo one; echo two"], restartDelay: 0.2) { line in
        received.lock.withLock { received.all.append(line) }
    }
    stream.start()
    try? await Task.sleep(for: .seconds(1))
    stream.stop()
    let got = received.lock.withLock { received.all }
    check("a stream's lines are read one by one", Array(got.prefix(2)) == ["one", "two"], "\(got)")
    check("a stream that ends is started again", stream.starts >= 2, "\(stream.starts) starts")
    let startsAtStop = stream.starts
    try? await Task.sleep(for: .seconds(0.6))
    check("a stopped stream stays stopped", stream.starts == startsAtStop)

    // A command that started others: on its time limit, they all end.
    let family = "3001\(getpid())"
    let familyStart = Date()
    let shell = await runner.run("/bin/sh", ["-c", "sleep \(family) & wait"], timeout: 0.5)
    check("a hung command and the processes it started all end at its limit", shell.timedOut && running("sleep \(family)") == 0,
        "\(running("sleep \(family)")) left after \(Date().timeIntervalSince(familyStart)) s")

    // A command that keeps writing past its limit, through a child: the output is read without blocking, the pipe is
    // closed under the read lock, and the whole family ends.
    let chatty = "3004\(getpid())"
    let chattyStart = Date()
    let flood = await runner.run("/bin/sh", ["-c", "while :; do echo x; /bin/sleep 0.\(chatty); done & wait"], timeout: 0.5)
    let chattyTook = Date().timeIntervalSince(chattyStart)
    check("a command still writing at its limit ends, with its output so far", flood.timedOut && chattyTook < 3, "took \(chattyTook) s")
    check("...and nothing of it keeps running", await waitUntil(2) { running("sleep 0.\(chatty)") == 0 })

    // A command that leaves a child holding its output open: the bar does not wait for that child.
    let orphan = "3002\(getpid())"
    let orphanStart = Date()
    let quick = await runner.run("/bin/sh", ["-c", "echo done; sleep \(orphan) &"], timeout: 5)
    let orphanTook = Date().timeIntervalSince(orphanStart)
    check("a child left holding the output open does not hold the bar", quick.stdout == "done\n" && orphanTook < 2, "took \(orphanTook) s")
    let cleanup = Process()
    cleanup.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
    cleanup.arguments = ["-f", "sleep \(orphan)$"]
    try? cleanup.run()
    cleanup.waitUntilExit()

    // A stream started twice, or stopped and started at once, runs one process.
    let once = LineStream("/bin/sleep", ["3003\(getpid())"], restartDelay: 0.2) { _ in }
    let streamed = "sleep 3003\(getpid())"
    once.start()
    once.start()
    _ = await waitUntil(3) { running(streamed) == 1 }
    try? await Task.sleep(for: .seconds(0.3))  // room for a second process, if one were coming
    check("a stream started twice runs one process", running(streamed) == 1 && once.starts == 1)
    once.stop()
    once.start()
    // The old process ends and the new one starts: wait for exactly one, then make sure it stays one.
    let one = await waitUntil(3) { running(streamed) == 1 && once.starts == 2 }
    try? await Task.sleep(for: .seconds(0.4))
    check("stopped and started at once, it still runs one", one && running(streamed) == 1, "\(running(streamed))")
    once.stop()
    check("stopped, nothing of it runs", await waitUntil(3) { running(streamed) == 0 })

    // The battery box: battery.sh's levels and colors.
    check("80% and up is full and green", BatteryStyle(percent: 80, onPower: false) == .full && BatteryStyle.full.color == 0xa6da95)
    check("70-79% is three quarters", BatteryStyle(percent: 79, onPower: false) == .threeQuarters)
    check("40-69% is half and peach", BatteryStyle(percent: 40, onPower: false) == .half && BatteryStyle.half.color == 0xf5a97f)
    check("10-39% is a quarter", BatteryStyle(percent: 10, onPower: false) == .quarter)
    check("under 10% is empty and red", BatteryStyle(percent: 9, onPower: false) == .empty && BatteryStyle.empty.color == 0xed8796)
    check("on power it is the yellow bolt, whatever the level", BatteryStyle(percent: 5, onPower: true) == .charging && BatteryStyle.charging.glyph == "\u{F0E7}")

    // The date and time boxes.
    let santiago = TimeZone(identifier: "America/Santiago")!
    let moment = Date(timeIntervalSince1970: 1_792_948_000)  // 2026-10-25 14:06:40 in Santiago
    check("the time box reads HH:mm", ClockText.time(moment, timeZone: santiago) == "14:06", ClockText.time(moment, timeZone: santiago))
    check("the date box reads dd-MM-yyyy", ClockText.date(moment, timeZone: santiago) == "25-10-2026", ClockText.date(moment, timeZone: santiago))
    check("the boxes are redrawn when the minute changes", ClockText.nextMinute(after: moment).timeIntervalSince(moment) == 20)

    // The moon box: moon.sh's phase for known dates.
    check("2026-10-24 is the full moon (moon.sh said 4)", MoonPhase.index(at: Date(timeIntervalSince1970: 1_792_871_376)) == 4)
    check("the known new moon is phase 0", MoonPhase.index(at: Date(timeIntervalSince1970: 947_182_440)) == 0)
    check("a week later is the first quarter", MoonPhase.index(at: Date(timeIntervalSince1970: 947_182_440 + 7.4 * 86_400)) == 2)

    // The glyphs, measured in the font: waxing phases are lit on the right, waning ones on the left, and every phase has
    // its own (the table used to repeat one at 5 and 7, so a waning gibbous moon was drawn as a crescent).
    check("each of the eight phases has its own glyph", Set(MoonPhase.glyphs).count == 8)
    check(
        "the glyphs go new, waxing crescent, first quarter, waxing gibbous, full, waning gibbous, last quarter, waning crescent",
        MoonPhase.glyphs == ["\u{E38D}", "\u{E38F}", "\u{E394}", "\u{E399}", "\u{E39B}", "\u{E39E}", "\u{E3A2}", "\u{E3A6}"])
    // 2026-10-27 (three days past the full moon) was a waning gibbous moon.
    let waningGibbous = MoonPhase.index(at: Date(timeIntervalSince1970: 1_792_871_376 + 3.4 * 86_400))
    check("three days past the full moon is a waning gibbous moon", MoonPhase.glyphs[waningGibbous] == "\u{E39E}")
}
