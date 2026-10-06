import Foundation
import GRDB

public protocol SecretStore {
    func password(for accountId: Int64) -> String?
    func setPassword(_ p: String, for accountId: Int64) throws
    func deletePassword(for accountId: Int64)
}

public final class MemorySecretStore: SecretStore {
    private var store: [Int64: String] = [:]
    public init() {}
    public func password(for id: Int64) -> String? { store[id] }
    public func setPassword(_ p: String, for id: Int64) throws { store[id] = p }
    public func deletePassword(for id: Int64) { store[id] = nil }
}

/// Stores account passwords in the app database (plain text, owner-only file permissions).
/// ponytail: not encrypted at rest; the Keychain was dropped on purpose (access prompts on every new build).
/// Upgrade path if needed: encrypt with a key derived from a per-install secret.
public final class DatabaseSecretStore: SecretStore {
    private let db: AppDatabase
    private let lock = NSLock()
    private var cache: [Int64: String?] = [:]      // read on the main thread for every row/play: never wait for the database
    public init(db: AppDatabase) { self.db = db }

    public func password(for id: Int64) -> String? {
        lock.lock(); let hit = cache[id]; lock.unlock()
        if let hit { return hit }
        guard let v = try? db.dbQueue.read({ try String.fetchOne($0, sql: "SELECT password FROM secret WHERE accountId = ?", arguments: [id]) })
        else { return nil }                          // a failed read is not cached (it would look like "no password")
        lock.lock(); cache[id] = .some(v); lock.unlock()
        return v
    }
    public func setPassword(_ p: String, for id: Int64) throws {
        try db.dbQueue.write {
            try $0.execute(sql: "INSERT INTO secret (accountId, password) VALUES (?, ?) ON CONFLICT(accountId) DO UPDATE SET password = excluded.password",
                           arguments: [id, p])
        }
        lock.lock(); cache[id] = .some(p); lock.unlock()
    }
    public func deletePassword(for id: Int64) {
        _ = try? db.dbQueue.write { try $0.execute(sql: "DELETE FROM secret WHERE accountId = ?", arguments: [id]) }
        lock.lock(); cache[id] = .some(nil); lock.unlock()
    }
}
