import Foundation
import Security

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

public struct KeychainSecretStore: SecretStore {
    public init() {}
    private func query(_ id: Int64) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "IPTVMac",
         kSecAttrAccount as String: "account-\(id)"]
    }
    public func password(for id: Int64) -> String? {
        var q = query(id); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    public func setPassword(_ p: String, for id: Int64) throws {
        deletePassword(for: id)
        var q = query(id); q[kSecValueData as String] = Data(p.utf8)
        let s = SecItemAdd(q as CFDictionary, nil)
        if s != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(s)) }
    }
    public func deletePassword(for id: Int64) { SecItemDelete(query(id) as CFDictionary) }
}
