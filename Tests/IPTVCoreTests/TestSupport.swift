import Foundation
import GRDB
@testable import IPTVCore

func makeDB() throws -> (AppDatabase, Int64) {
    let db = try AppDatabase()
    let id = try db.dbQueue.write { d -> Int64 in
        var a = Account(name: "t", kind: .xtream, server: "http://h", username: "u")
        try a.insert(d)
        return a.id!
    }
    return (db, id)
}

func addItem(_ db: AppDatabase, _ aid: Int64, _ name: String, type: ItemType = .live,
             cat: String? = "1", sid: String? = nil) throws {
    try db.dbQueue.write { d in
        var i = Item(accountId: aid, type: type, name: name, streamId: sid ?? name, categoryId: cat)
        try i.insert(d)
    }
}
