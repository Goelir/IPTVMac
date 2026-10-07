import Foundation
import Testing
@testable import IPTVCore

@Test func autoRefreshOffNeverFires() {
    let t = Date(timeIntervalSince1970: 1_000_000)
    #expect(!RefreshSchedule.isDue(hours: 0, lastSync: nil, now: t))
    #expect(!RefreshSchedule.isDue(hours: 0, lastSync: t.addingTimeInterval(-999 * 3600), now: t))
}

@Test func autoRefreshFiresOnceTheIntervalHasElapsed() {
    let last = Date(timeIntervalSince1970: 1_000_000)
    #expect(!RefreshSchedule.isDue(hours: 6, lastSync: last, now: last.addingTimeInterval(6 * 3600 - 1)))
    #expect(RefreshSchedule.isDue(hours: 6, lastSync: last, now: last.addingTimeInterval(6 * 3600)))
    #expect(!RefreshSchedule.isDue(hours: 24, lastSync: last, now: last.addingTimeInterval(23 * 3600)))
    #expect(RefreshSchedule.isDue(hours: 24, lastSync: last, now: last.addingTimeInterval(25 * 3600)))
}

@Test func autoRefreshWithoutAPreviousSyncIsDueAndAClockThatJumpedBackToo() {
    let t = Date(timeIntervalSince1970: 1_000_000)
    #expect(RefreshSchedule.isDue(hours: 12, lastSync: nil, now: t))
    #expect(RefreshSchedule.isDue(hours: 12, lastSync: t.addingTimeInterval(3600), now: t))
}
