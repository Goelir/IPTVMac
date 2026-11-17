import XCTest
import StoreKitTest
import StoreKit
@testable import IPTVPhone

/// The tip jar against a local StoreKit configuration (Tips.storekit): no App Store, no money.
/// Each test opens its own session (a session made in an async setUp of a @MainActor class served no products).
final class TipJarTests: XCTestCase {
    private func session() throws -> SKTestSession {
        let s = try SKTestSession(configurationFileNamed: "Tips")
        s.resetToDefaultState(); s.disableDialogs = true; s.clearTransactions()
        return s
    }

    func testTheThreeTipsLoadInPriceOrder() async throws {
        let s = try session()
        let jar = await TipJar()
        await jar.load()
        let ids = await jar.products.map(\.id)
        XCTAssertEqual(ids, TipJar.productIDs)
        _ = s
    }

    func testATipThanksAndIsFinishedAndCanBeGivenAgain() async throws {
        let s = try session()
        let jar = await TipJar()
        await jar.load()
        let first = await jar.products.first
        let small = try XCTUnwrap(first)
        await jar.buy(small)
        var status = await jar.status
        XCTAssertEqual(status, .thanked)
        await jar.buy(small)                                   // consumable: the same tip can be given again
        status = await jar.status
        XCTAssertEqual(status, .thanked)
        XCTAssertEqual(s.allTransactions().count, 2)
        // finish() reaches the local store a moment later: give it up to 3 s before calling a tip unfinished
        var left: [String] = []
        for _ in 0..<30 {
            left = []
            for await r in Transaction.unfinished { if case .verified(let t) = r { left.append("\(t.id) \(t.productID)") } }
            if left.isEmpty { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(left, [], "tips left unfinished")
    }

    func testAFailedPurchaseShowsTheFailureNotTheThanks() async throws {
        let s = try session()
        s.failTransactionsEnabled = true
        let jar = await TipJar()
        await jar.load()
        let last = await jar.products.last
        await jar.buy(try XCTUnwrap(last))
        let status = await jar.status
        XCTAssertEqual(status, .failed)
        s.failTransactionsEnabled = false
    }

    func testNoProductsWhenTheStoreHasNone() async throws {
        let s = try session()
        let jar = await TipJar(ids: ["io.github.goelir.IPTVMac.tip.missing"])
        await jar.load()
        let empty = await jar.products.isEmpty
        XCTAssertTrue(empty)                                   // the About screen then shows no tip section
        _ = s
    }
}
