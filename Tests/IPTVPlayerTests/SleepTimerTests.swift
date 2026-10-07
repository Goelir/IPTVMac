import Testing
import Foundation
@testable import IPTVPlayer

private let t0 = Date(timeIntervalSince1970: 1_000_000)

@Test func sleepTimerStartsOff() {
    let t = SleepTimer()
    #expect(!t.isActive)
    #expect(t.remaining(now: t0) == nil)
    #expect(t.remainingMinutes(now: t0) == nil)
    #expect(!t.expired(now: t0))
}

@Test func sleepTimerCountsDownAndExpiresAtTheDeadline() {
    var t = SleepTimer()
    t.set(minutes: 15, now: t0)
    #expect(t.isActive)
    #expect(t.remaining(now: t0) == 900)
    #expect(t.remaining(now: t0 + 600) == 300)
    #expect(!t.expired(now: t0 + 899))
    #expect(t.expired(now: t0 + 900))
    #expect(t.expired(now: t0 + 5000))
    #expect(t.remaining(now: t0 + 5000) == 0, "the remaining time never goes negative")
}

@Test(arguments: [(0.0, 15), (1.0, 15), (59.0, 15), (60.0, 14), (840.0, 1), (899.0, 1), (900.0, 0), (1200.0, 0)])
func remainingMinutesRoundUp(_ elapsed: Double, _ minutes: Int) {
    var t = SleepTimer()
    t.set(minutes: 15, now: t0)
    #expect(t.remainingMinutes(now: t0 + elapsed) == minutes)
}

@Test func cancelAndZeroTurnItOff() {
    var t = SleepTimer()
    t.set(minutes: 30, now: t0)
    t.cancel()
    #expect(!t.isActive && !t.expired(now: t0 + 99_999) && t.remaining(now: t0) == nil)
    t.set(minutes: 30, now: t0)
    t.set(minutes: 0, now: t0)
    #expect(!t.isActive, "0 minutes is the Off entry")
    t.set(minutes: -5, now: t0)
    #expect(!t.isActive)
}

@Test func settingAgainReplacesTheDeadline() {
    var t = SleepTimer()
    t.set(minutes: 15, now: t0)
    t.set(minutes: 60, now: t0 + 600)
    #expect(t.remaining(now: t0 + 600) == 3600)
    #expect(!t.expired(now: t0 + 900))
}
