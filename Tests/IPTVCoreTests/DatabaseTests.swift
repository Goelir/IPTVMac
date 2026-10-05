import Testing
import GRDB
@testable import IPTVCore

@Test func fts5IsKeptInSyncWithItems() throws {
    let (db, aid) = try makeDB()
    try addItem(db, aid, "Hello World")
    let hits = try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item_fts WHERE item_fts MATCH 'hello'") }
    #expect(hits == 1)
    try db.dbQueue.write { try $0.execute(sql: "DELETE FROM item") }
    let after = try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item_fts WHERE item_fts MATCH 'hello'") }
    #expect(after == 0)
}

@Test func duplicateStreamIdIsRejected() throws {
    let (db, aid) = try makeDB()
    try addItem(db, aid, "A", sid: "1")
    #expect(throws: (any Error).self) { try addItem(db, aid, "B", sid: "1") }
}
