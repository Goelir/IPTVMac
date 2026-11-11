import XCTest
import IPTVCore
import IPTVAppKit
@testable import IPTVPhone

/// The parts of the iPhone/iPad app that need the app or the real keychain: the simulator runs these (`xcodebuild test`).
final class AppLayerTests: XCTestCase {
    func testSystemKeychainRoundTrip() throws {
        let k = SystemKeychain(service: "io.github.goelir.IPTVMac.tests.\(UUID().uuidString)")
        defer { k.delete("a") }
        XCTAssertNil(try k.read("a"))
        try k.write("v1:secret", key: "a")
        XCTAssertEqual(try k.read("a"), "v1:secret")
        try k.write("v1:changed", key: "a")                              // an existing item is updated, not duplicated
        XCTAssertEqual(try k.read("a"), "v1:changed")
        k.delete("a")
        XCTAssertNil(try k.read("a"))
    }

    @MainActor func testAddingAnXtreamSourceKeepsThePasswordOutOfTheDatabase() async throws {
        let db = try AppDatabase()
        let store = KeychainSecretStore(backing: SystemKeychain(service: "io.github.goelir.IPTVMac.tests.\(UUID().uuidString)"), legacy: DatabaseSecretStore(db: db))
        let m = LibraryModel(db: db, secrets: store)
        // no network: the sync after saving fails, the account and its password are saved first
        await m.addAccount(Account(name: "T", kind: .xtream, server: "http://127.0.0.1:9", username: "u"), password: "pw")
        let id = try XCTUnwrap(m.accounts.first?.id)
        XCTAssertEqual(store.password(for: id), "pw")
        let rows = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM secret") }
        XCTAssertEqual(rows, 0)
        m.deleteAccount(m.accounts[0])
        XCTAssertNil(store.password(for: id))
    }

    func testMonogramIsStableAndHandlesAnyScript() {
        XCTAssertEqual(Monogram.initials("Harbor News 24"), "HN")
        XCTAssertEqual(Monogram.initials("חדשות הנמל 24"), "חה")
        XCTAssertEqual(Monogram.initials("  "), "")
        XCTAssertEqual(Monogram.initials("CNN"), "C")
        XCTAssertEqual(Monogram.hue("Planet Docs"), Monogram.hue("Planet Docs"))   // the same name always gets the same colour, in every launch
        XCTAssertTrue((0.50...0.68).contains(Monogram.hue("anything")))
    }

    func testSectionsMapToTheModelsTypes() {
        for t in ItemType.allCases { XCTAssertEqual(AppSection(t).itemType, t) }
        XCTAssertNil(AppSection.library.itemType); XCTAssertNil(AppSection.settings.itemType)
    }

    func testEveryNewStringKeyIsLocalizedInTheBundle() {
        // the keys the screens use must resolve (a missing key shows the key itself)
        for k in ["tab.library", "settings.title", "onb.noChannels", "password.body.ios", "series.playEp", "sync.now"] {
            XCTAssertNotEqual(L(k), k, "\(k) is missing from Localizable.strings")
        }
    }

    /// A provider's 2000x3000 poster must not stay that big in memory: it is shrunk to what the grid needs, once, and then served from memory.
    func testImageStoreShrinksAndCaches() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("poster-\(UUID().uuidString).png")
        let big = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 3000), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
            .pngData { ctx in UIColor.purple.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 2000, height: 3000)) }
        try big.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(ImageStore.shared.cached(url, maxPixel: 300))
        let img = await ImageStore.shared.image(url, maxPixel: 300)
        let px = try XCTUnwrap(img).size.height * img!.scale
        XCTAssertLessThanOrEqual(px, 300)
        XCTAssertNotNil(ImageStore.shared.cached(url, maxPixel: 300))               // the grid's next scroll past it costs nothing
        XCTAssertNil(ImageStore.shared.cached(url, maxPixel: 900))                  // another size is another entry
    }
}
