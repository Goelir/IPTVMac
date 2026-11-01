import Foundation
import Testing
import GRDB
@testable import IPTVCore

@Test func aSavedLanguageFindsItsTrackInTheNextEpisode() {
    let tracks: [(id: Int, lang: String?, title: String?)] = [(1, "eng", nil), (2, "heb", "Hebrew"), (3, nil, "Commentary")]
    #expect(SeriesPrefsLogic.action(for: .language("heb"), tracks: tracks) == .track(2))
    #expect(SeriesPrefsLogic.action(for: .language("HEB"), tracks: tracks) == .track(2))          // case does not matter
    #expect(SeriesPrefsLogic.action(for: .language("commentary"), tracks: tracks) == .track(3))   // a track without a language is found by its title
    #expect(SeriesPrefsLogic.action(for: .language("fra"), tracks: tracks) == nil)                // not in this episode: the default stays
    #expect(SeriesPrefsLogic.action(for: .off, tracks: tracks) == .off)
    #expect(SeriesPrefsLogic.action(for: nil, tracks: tracks) == nil)
}

@Test func theChoiceOfATrackIsItsLanguageOrItsTitle() {
    #expect(SubtitleChoice.of(lang: " HEB ", title: "x") == .language("heb"))
    #expect(SubtitleChoice.of(lang: nil, title: "Commentary") == .language("commentary"))
    #expect(SubtitleChoice.of(lang: "", title: nil) == nil)
}

@Test func prefsAreSavedPerSeriesAndEmptyPrefsRemoveTheRow() throws {
    let (db, a) = try makeDB()
    func load(_ s: String) throws -> SeriesPrefs { try db.dbQueue.read { try UserData.seriesPrefs($0, accountId: a, seriesId: s) } }
    #expect(try load("9").isEmpty)
    try db.dbQueue.write { d in
        try UserData.saveSeriesPrefs(d, accountId: a, seriesId: "9", prefs: SeriesPrefs(speed: 1.5, subtitle: .language("heb")))
        try UserData.saveSeriesPrefs(d, accountId: a, seriesId: "10", prefs: SeriesPrefs(subtitle: .off))
    }
    #expect(try load("9") == SeriesPrefs(speed: 1.5, subtitle: .language("heb")))
    #expect(try load("10") == SeriesPrefs(speed: nil, subtitle: .off))                         // "off" is a choice, not "no choice"
    try db.dbQueue.write { try UserData.saveSeriesPrefs($0, accountId: a, seriesId: "9", prefs: SeriesPrefs(speed: 2)) }
    #expect(try load("9") == SeriesPrefs(speed: 2, subtitle: nil))
    try db.dbQueue.write { try UserData.saveSeriesPrefs($0, accountId: a, seriesId: "9", prefs: SeriesPrefs()) }
    #expect(try load("9").isEmpty)
    try db.dbQueue.write { try $0.execute(sql: "DELETE FROM account WHERE id = ?", arguments: [a]) }
    #expect(try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM series_prefs") } == 0)
}
