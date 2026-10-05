import Testing
import Foundation
@testable import IPTVCore

/// Xtream API URLs contain the account password; they must never be written to the on-disk URL cache.
@Test func apiSessionNeverCaches() {
    #expect(apiSession.configuration.urlCache == nil)
    #expect(apiSession.configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
}
