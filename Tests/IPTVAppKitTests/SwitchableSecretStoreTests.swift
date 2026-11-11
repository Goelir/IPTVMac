import Testing
import Foundation
import IPTVCore
@testable import IPTVAppKit

private final class RefusingStore: SecretStore {
    func password(for id: Int64) -> String? { nil }
    func setPassword(_ p: String, for id: Int64) throws { throw KeychainError(status: -25293) }
    func deletePassword(for id: Int64) {}
}

@Test func switchingToTheKeychainMovesEveryPasswordAndBack() throws {
    let db = MemorySecretStore(), kc = MemorySecretStore()
    try db.setPassword("a", for: 1); try db.setPassword("", for: 2)
    let s = SwitchableSecretStore(database: db, keychain: kc, usesKeychain: false)
    try s.use(keychain: true, ids: [1, 2, 3])
    #expect(s.usesKeychain && kc.password(for: 1) == "a" && kc.password(for: 2) == "" && db.password(for: 1) == nil)
    try s.setPassword("b", for: 1)
    #expect(kc.password(for: 1) == "b")
    try s.use(keychain: false, ids: [1, 2])
    #expect(!s.usesKeychain && db.password(for: 1) == "b" && kc.password(for: 1) == nil && s.password(for: 2) == "")
}

@Test func aRefusedKeychainChangesNothing() throws {
    let db = MemorySecretStore()
    try db.setPassword("a", for: 1)
    let s = SwitchableSecretStore(database: db, keychain: RefusingStore(), usesKeychain: false)
    #expect(throws: KeychainError.self) { try s.use(keychain: true, ids: [1]) }
    #expect(!s.usesKeychain && s.password(for: 1) == "a")
}
