import Foundation
import Testing
@testable import IPTVCore

private func fresh() -> ReviewPrompt {
    let name = "review-test-\(UUID().uuidString)"
    return ReviewPrompt(defaults: UserDefaults(suiteName: name)!)
}

@Test func reviewAsksOnlyAfterFiveRealViewsAndThreeDays() {
    let p = fresh(), t0 = Date(timeIntervalSince1970: 1_000_000), day: TimeInterval = 86_400
    p.noteLaunch(now: t0)
    p.noteLaunch(now: t0 + 10 * day)                       // later launches do not move the first one
    for _ in 0..<4 { p.notePlayback(watched: 600) }
    p.notePlayback(watched: 299)                           // under 5 minutes: not a view
    #expect(!p.shouldAsk(version: "1.0.3", now: t0 + 4 * day))
    p.notePlayback(watched: 300)
    #expect(!p.shouldAsk(version: "1.0.3", now: t0 + 3 * day - 1))
    #expect(p.shouldAsk(version: "1.0.3", now: t0 + 3 * day))
}

@Test func reviewAsksOncePerVersion() {
    let p = fresh(), t0 = Date(timeIntervalSince1970: 1_000_000)
    p.noteLaunch(now: t0)
    for _ in 0..<5 { p.notePlayback(watched: 3600) }
    let later = t0 + 30 * 86_400
    #expect(p.shouldAsk(version: "1.0.3", now: later))
    #expect(!p.shouldAsk(version: "1.0.3", now: later))
    #expect(p.shouldAsk(version: "1.0.4", now: later))
}

@Test func reviewNeverAsksWithoutAKnownFirstLaunch() {
    let p = fresh()
    for _ in 0..<9 { p.notePlayback(watched: 3600) }
    #expect(!p.shouldAsk(version: "1.0.3"))
}
