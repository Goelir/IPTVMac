import Foundation
import Security
import IPTVCore

/// Where the secrets physically live. The system keychain in the app, a dictionary in tests.
public protocol KeychainBacking: AnyObject {
    /// nil = no such item; a throw = the keychain could not be read (not the same thing).
    func read(_ key: String) throws -> String?
    func write(_ value: String, key: String) throws
    func delete(_ key: String)
}

public struct KeychainError: Error, LocalizedError, Equatable {
    public let status: OSStatus
    public var errorDescription: String? { (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)" }
}

/// The system keychain: generic passwords. iOS: readable after the first unlock, never synced or backed up to another device.
public final class SystemKeychain: KeychainBacking {
    private let service: String
    public init(service: String = "io.github.goelir.IPTVMac.provider") { self.service = service }

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }

    public func read(_ key: String) throws -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let s = SecItemCopyMatching(q as CFDictionary, &out)
        if s == errSecItemNotFound { return nil }
        guard s == errSecSuccess, let d = out as? Data else { throw KeychainError(status: s) }
        return String(data: d, encoding: .utf8)
    }

    public func write(_ value: String, key: String) throws {
        let data = Data(value.utf8)
        let u = SecItemUpdate(query(key) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if u == errSecSuccess { return }
        guard u == errSecItemNotFound else { throw KeychainError(status: u) }
        var q = query(key)
        q[kSecValueData as String] = data
        #if os(iOS)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif   // macOS: the login keychain; the data-protection keychain needs a provisioning profile the Developer ID build has not
        let a = SecItemAdd(q as CFDictionary, nil)
        guard a == errSecSuccess else { throw KeychainError(status: a) }
    }

    public func delete(_ key: String) { SecItemDelete(query(key) as CFDictionary) }
}

/// Provider passwords in the keychain (iOS). `legacy` is the database store an earlier build used: a password found only
/// there moves to the keychain on first read. Reads are cached: the lists ask for a password on every row that appears.
public final class KeychainSecretStore: SecretStore {
    private let backing: KeychainBacking
    private let legacy: SecretStore?
    private let lock = NSLock()
    private var cache: [Int64: String?] = [:]
    /// A prefix keeps "no password" (an empty string) a non-empty item, which the keychain stores without special cases.
    private static let prefix = "v1:"

    public init(backing: KeychainBacking = SystemKeychain(), legacy: SecretStore? = nil) {
        self.backing = backing; self.legacy = legacy
    }

    private func key(_ id: Int64) -> String { "account-\(id)" }

    public func password(for id: Int64) -> String? {
        lock.lock(); let hit = cache[id]; lock.unlock()
        if let hit { return hit }
        let stored: String?
        do { stored = try backing.read(key(id)) } catch { return nil }       // a failed read is not cached (it would look like "no password")
        var value = stored.flatMap { $0.hasPrefix(Self.prefix) ? String($0.dropFirst(Self.prefix.count)) : nil }
        if value == nil, let old = legacy?.password(for: id) {
            if (try? backing.write(Self.prefix + old, key: key(id))) != nil { legacy?.deletePassword(for: id) }
            value = old
        }
        lock.lock(); cache[id] = .some(value); lock.unlock()
        return value
    }

    public func setPassword(_ p: String, for id: Int64) throws {
        try backing.write(Self.prefix + p, key: key(id))
        legacy?.deletePassword(for: id)
        lock.lock(); cache[id] = .some(p); lock.unlock()
    }

    public func deletePassword(for id: Int64) {
        backing.delete(key(id)); legacy?.deletePassword(for: id)
        lock.lock(); cache[id] = .some(nil); lock.unlock()
    }
}

/// macOS: the owner picks where passwords live (Settings > Playlists). Off = the app database (no prompts, even for unsigned
/// builds); on = the login keychain. Switching moves every password across, or nothing when one write fails.
public final class SwitchableSecretStore: SecretStore {
    private let database: SecretStore, keychain: SecretStore
    public private(set) var usesKeychain: Bool
    private var current: SecretStore { usesKeychain ? keychain : database }

    public init(database: SecretStore, keychain: SecretStore, usesKeychain: Bool) {
        self.database = database; self.keychain = keychain; self.usesKeychain = usesKeychain
    }

    public func password(for id: Int64) -> String? { current.password(for: id) }
    public func setPassword(_ p: String, for id: Int64) throws { try current.setPassword(p, for: id) }
    public func deletePassword(for id: Int64) { current.deletePassword(for: id) }

    /// Moves the passwords of `ids` to the chosen store. A failure (the keychain refused) undoes the copies and throws.
    public func use(keychain on: Bool, ids: [Int64]) throws {
        guard on != usesKeychain else { return }
        let from = current, to = on ? keychain : database
        var copied: [Int64] = []
        do {
            for id in ids { if let p = from.password(for: id) { try to.setPassword(p, for: id); copied.append(id) } }
        } catch {
            for id in copied { to.deletePassword(for: id) }
            throw error
        }
        for id in copied { from.deletePassword(for: id) }
        usesKeychain = on
    }
}
