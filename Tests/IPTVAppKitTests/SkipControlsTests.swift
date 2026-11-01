import Testing
import Foundation
import IPTVCore
@testable import IPTVAppKit

@MainActor private func controls(_ marks: SkipMarks = SkipMarks(), saved: SavedBox = SavedBox(), noticeSeconds: Double = 0.05) -> SkipControls {
    SkipControls(marks: marks, noticeSeconds: noticeSeconds) { saved.value.append($0) }
}
final class SavedBox: @unchecked Sendable { var value: [SkipMarks] = [] }

@MainActor @Test func theOfferFollowsThePositionAndTheMarks() {
    let c = controls(SkipMarks(introStart: 10, introEnd: 100, creditsLen: 60))
    c.update(position: 5, duration: 1500);    #expect(c.offer == nil)
    c.update(position: 20, duration: 1500);   #expect(c.offer == .intro(to: 100))
    c.update(position: 300, duration: 1500);  #expect(c.offer == nil)
    c.update(position: 1450, duration: 1500); #expect(c.offer == .credits)
}

@MainActor @Test func markingSavesAndShowsTheOfferAtOnce() async throws {
    let box = SavedBox(), c = controls(saved: box)
    c.markIntroEnd(position: 90, duration: 1500)
    #expect(c.marks.introEnd == 90 && box.value.last?.introEnd == 90 && c.notice == .saved)
    c.update(position: 10, duration: 1500)
    #expect(c.offer == .intro(to: 90))
    c.markCredits(position: 1400, duration: 1500)
    #expect(c.marks.creditsLen == 100)
    try await Task.sleep(for: .milliseconds(200))
    #expect(c.notice == nil)                                         // the message goes away by itself
}

@MainActor @Test func aMarkThatMakesNoSenseIsRefusedAndNothingIsSaved() {
    let box = SavedBox(), c = controls(saved: box)
    c.markCredits(position: 100, duration: 1500)                     // credits in the first half
    #expect(c.notice == .refused && box.value.isEmpty && c.marks.isEmpty)
}

@MainActor @Test func forgettingClearsEverything() {
    let box = SavedBox(), c = controls(SkipMarks(introEnd: 90, creditsLen: 80), saved: box)
    c.update(position: 10, duration: 1500); #expect(c.offer != nil)
    c.forget()
    #expect(c.marks.isEmpty && c.offer == nil && box.value.last?.isEmpty == true)
}

@MainActor @Test func resumeStartsTheEpisodeThatWasLeftAtItsMinute() async throws {
    final class Recorder: LibraryModel {
        var started: PlayRequest?
        override func startPlayback(_ r: PlayRequest) { started = r; super.startPlayback(r) }
    }
    let secrets = MemorySecretStore()
    let m = Recorder(db: try AppDatabase(), secrets: secrets)
    let (aid, series) = try await m.db.dbQueue.write { d -> (Int64, Item) in
        var a = Account(name: "a", kind: .xtream, server: "http://h:80", username: "u"); try a.insert(d)
        var s = Item(accountId: a.id!, type: .series, name: "Show", streamId: "20"); try s.insert(d)
        for (sn, n, sid) in [(1, 1, "101"), (1, 2, "102"), (1, 3, "103")] { var e = Episode(accountId: a.id!, seriesId: "20", season: sn, number: n, title: "t\(n)", streamId: sid, containerExt: "mkv"); try e.insert(d) }
        try UserData.saveProgress(d, accountId: a.id!, type: .series, streamId: "ep:102", position: 600, duration: 2400)
        return (a.id!, s)
    }
    try secrets.setPassword("p", for: aid)
    m.loadAccounts()
    let entry = try await m.db.dbQueue.read { try WatchProgress.continueEntries($0, accountId: aid, type: .series) }[0]
    #expect(entry.item.id == series.id && entry.episodeId == "102")
    m.resume(entry)
    #expect(m.started?.episodeKey == "ep:102" && m.started?.start == 600 && m.started?.url.pathExtension == "mkv")
    #expect(m.started?.item?.streamId == "20")                       // an episode's request carries its series
}
