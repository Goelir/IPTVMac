import XCTest
import SwiftUI
import StoreKitTest
@testable import IPTVPhone

/// Only for a look at the tip section: shows Settings > About with the local StoreKit products for 12 s and writes a marker file so a
/// screenshot can be taken from outside (`TEST_RUNNER_TIPS_SCREENSHOT=1 xcodebuild test ...`). Skipped otherwise.
final class TipJarScreenshotTest: XCTestCase {
    @MainActor func testShowAboutWithTips() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TIPS_SCREENSHOT"] == "1")
        let s = try SKTestSession(configurationFileNamed: "Tips")
        s.resetToDefaultState(); s.disableDialogs = true; s.clearTransactions()
        await TipJar.shared.load()
        if ProcessInfo.processInfo.environment["TIPS_THANKED"] == "1", let p = TipJar.shared.products.first { await TipJar.shared.buy(p) }
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first)
        window.rootViewController = UIHostingController(rootView: NavigationStack { AboutScreen() })
        try await Task.sleep(for: .seconds(2))
        FileManager.default.createFile(atPath: "/tmp/iptv-tips-ready", contents: nil)
        try await Task.sleep(for: .seconds(12))
        _ = s
    }
}
