import Foundation
import Testing
import GRDB
@testable import IPTVCore

@Test func introIsOfferedFromItsStartUntilItsEnd() {
    let m = SkipMarks(introStart: 30, introEnd: 120)
    #expect(SkipLogic.offer(m, position: 10, duration: 2700) == nil)               // the cold open: before the intro
    #expect(SkipLogic.offer(m, position: 30, duration: 2700) == .intro(to: 120))
    #expect(SkipLogic.offer(m, position: 119, duration: 2700) == nil)              // about to end: no button
    #expect(SkipLogic.offer(m, position: 300, duration: 2700) == nil)
    #expect(SkipLogic.offer(SkipMarks(introEnd: 90), position: 0, duration: 2700) == .intro(to: 90))   // no start: from the first second
}

@Test func creditsAreOfferedInTheLastStretch() {
    let m = SkipMarks(creditsLen: 90)
    #expect(SkipLogic.offer(m, position: 2000, duration: 2700) == nil)
    #expect(SkipLogic.offer(m, position: 2610, duration: 2700) == .credits)
    #expect(SkipLogic.offer(m, position: 2699, duration: 2700) == nil)            // the very end: nothing left to skip
    #expect(SkipLogic.offer(m, position: 10, duration: 0) == nil)                 // duration unknown
    #expect(SkipLogic.offer(SkipMarks(creditsLen: 2), position: 2698, duration: 2700) == nil)   // too short to be credits
}

@Test func creditsLengthAppliesToEpisodesOfOtherLengths() {
    let m = SkipMarks(creditsLen: 120)
    #expect(SkipLogic.offer(m, position: 1500 - 119, duration: 1500) == .credits)
    #expect(SkipLogic.offer(m, position: 1500 - 200, duration: 1500) == nil)
}

@Test func anIntroEndBeyondTheMiddleIsIgnored() {
    #expect(SkipLogic.offer(SkipMarks(introEnd: 2000), position: 100, duration: 2700) == nil)
}

@Test func marksAreAcceptedOnlyWhereTheyMakeSense() {
    var m = SkipMarks()
    #expect(SkipLogic.markIntroEnd(m, position: 1, duration: 2700) == nil)                   // an intro must have some length
    m = SkipLogic.markIntroEnd(m, position: 95, duration: 2700)!
    #expect(m.introEnd == 95)
    #expect(SkipLogic.markIntroEnd(m, position: 2000, duration: 2700) == nil)                // past the middle
    let s = SkipLogic.markIntroStart(m, position: 20, duration: 2700)!
    #expect(s.introStart == 20 && s.introEnd == 95)
    #expect(SkipLogic.markIntroStart(s, position: 100, duration: 2700)!.introEnd == nil)     // the end was before the new start: dropped
    #expect(SkipLogic.markIntroStart(s, position: 0.4, duration: 2700)!.introStart == nil)   // at the very start = no start
    #expect(SkipLogic.markCredits(m, position: 1000, duration: 2700) == nil)                 // credits are not in the first half
    #expect(SkipLogic.markCredits(m, position: 2699, duration: 2700) == nil)
    #expect(SkipLogic.markCredits(m, position: 2600, duration: 2700)!.creditsLen == 100)
}

@Test func marksAreSavedPerSeriesAndEmptyMarksRemoveTheRow() throws {
    let (db, a) = try makeDB()
    #expect(try db.dbQueue.read { try UserData.skipMarks($0, accountId: a, seriesId: "9") }.isEmpty)
    try db.dbQueue.write { try UserData.saveSkipMarks($0, accountId: a, seriesId: "9", marks: SkipMarks(introStart: 12, introEnd: 80, creditsLen: 70)) }
    try db.dbQueue.write { try UserData.saveSkipMarks($0, accountId: a, seriesId: "10", marks: SkipMarks(introEnd: 50)) }
    #expect(try db.dbQueue.read { try UserData.skipMarks($0, accountId: a, seriesId: "9") } == SkipMarks(introStart: 12, introEnd: 80, creditsLen: 70))
    #expect(try db.dbQueue.read { try UserData.skipMarks($0, accountId: a, seriesId: "10") } == SkipMarks(introEnd: 50))
    try db.dbQueue.write { try UserData.saveSkipMarks($0, accountId: a, seriesId: "9", marks: SkipMarks(introEnd: 85)) }   // an update replaces all three
    #expect(try db.dbQueue.read { try UserData.skipMarks($0, accountId: a, seriesId: "9") } == SkipMarks(introEnd: 85))
    try db.dbQueue.write { try UserData.saveSkipMarks($0, accountId: a, seriesId: "9", marks: SkipMarks()) }
    #expect(try db.dbQueue.read { try UserData.skipMarks($0, accountId: a, seriesId: "9") }.isEmpty)
}

@Test func marksGoWithTheirPlaylist() throws {
    let (db, a) = try makeDB()
    try db.dbQueue.write { try UserData.saveSkipMarks($0, accountId: a, seriesId: "9", marks: SkipMarks(introEnd: 80)) }
    try db.dbQueue.write { try $0.execute(sql: "DELETE FROM account WHERE id = ?", arguments: [a]) }
    #expect(try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM series_marks") } == 0)
}
