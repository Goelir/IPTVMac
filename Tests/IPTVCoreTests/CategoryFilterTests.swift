import Foundation
import Testing
import GRDB
@testable import IPTVCore

@Test func hiddenWordsAreTrimmedLowercasedAndEmptyOnesIgnored() {
    #expect(CategoryFilter("  Adult , XXX,, ,\n18+ ").words == ["adult", "xxx", "18+"])
    #expect(CategoryFilter("كبار،xxx, adult").words == ["كبار", "xxx", "adult"])        // the Arabic comma too
    #expect(CategoryFilter("").isEmpty)
    #expect(CategoryFilter(" , ,, ").isEmpty)
}

@Test func categoryNamesAreMatchedBySubstringIgnoringCase() {
    let f = CategoryFilter("adult, חדשות")
    #expect(f.hides("XXX ADULT 18+"))
    #expect(f.hides("Hot adults"))
    #expect(f.hides("ערוצי חדשות"))
    #expect(!f.hides("Movies"))
    #expect(!CategoryFilter("").hides("anything"))
}

@Test func hiddenCategoriesDisappearFromTheCategoryList() {
    let cats = [Category(accountId: 1, type: .live, remoteId: "1", name: "News"), Category(accountId: 1, type: .live, remoteId: "2", name: "Adult")]
    #expect(CategoryFilter("adult").visible(cats).map(\.name) == ["News"])
    #expect(CategoryFilter("").visible(cats).count == 2)
}

private func seed() throws -> (AppDatabase, Int64, Int64) {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "second")
    try db.dbQueue.write { d in
        for (aid, type, rid, name) in [(a, ItemType.live, "1", "News"), (a, .live, "2", "Adult"), (a, .movie, "2", "Action"), (b, .live, "2", "Sports")] {
            var c = Category(accountId: aid, type: type, remoteId: rid, name: name); try c.insert(d)
        }
    }
    try addItem(db, a, "Channel", cat: "1", sid: "c1"); try addItem(db, a, "Hidden channel", cat: "2", sid: "c2")
    try addItem(db, a, "Film", type: .movie, cat: "2", sid: "m1")          // remote id 2, but the movie category "Action"
    try addItem(db, a, "No category", cat: nil, sid: "c3"); try addItem(db, a, "Unknown category", cat: "99", sid: "c4")
    try addItem(db, b, "Other playlist", cat: "2", sid: "c2")              // same remote id in another playlist: "Sports"
    return (db, a, b)
}

@Test func itemsOfHiddenCategoriesAreRemovedPerPlaylistAndType() throws {
    let (db, _, _) = try seed()
    let all = try db.dbQueue.read { try Item.order(Column("id")).fetchAll($0) }
    let shown = try db.dbQueue.read { try CategoryFilter("adult").visible(all, in: $0) }.map(\.name)
    #expect(shown == ["Channel", "Film", "No category", "Unknown category", "Other playlist"])
}

@Test func anEmptyFilterReturnsEverything() throws {
    let (db, _, _) = try seed()
    let all = try db.dbQueue.read { try Item.fetchAll($0) }
    #expect(try db.dbQueue.read { try CategoryFilter(" , ").visible(all, in: $0) } == all)
}

@Test func hidingAppliesToFavoritesContinueWatchingAndSearchResults() throws {
    let (db, a, _) = try seed()
    try db.dbQueue.write { d in
        for sid in ["c1", "c2"] {
            _ = try UserData.toggleFavorite(d, accountId: a, type: .live, streamId: sid)
            try UserData.saveProgress(d, accountId: a, type: .live, streamId: sid, position: 10, duration: 100)
        }
    }
    let f = CategoryFilter("adult")
    let (favs, hist, found) = try db.dbQueue.read { d in
        (try f.visible(UserData.favorites(d, accountId: nil, type: .live), in: d).map(\.name),
         try f.visible(UserData.continueWatching(d, accountId: nil, type: .live), in: d).map(\.name),
         try f.visible(Search.run(d, SearchRequest(accountId: nil, text: "channel", type: .live)), in: d).map(\.name))
    }
    #expect(favs == ["Channel"] && hist == ["Channel"] && found == ["Channel"])
}
