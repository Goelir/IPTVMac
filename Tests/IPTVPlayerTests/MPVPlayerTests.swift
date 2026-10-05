import Testing
import Foundation
@testable import IPTVPlayer

/// Real libmpv, synthetic lavfi source (no network, no display): proves the engine links, loads and plays.
@Test func enginePlaysSyntheticSource() async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null")
    p.load("av://lavfi:testsrc=size=320x240:rate=25", start: 0)
    var pos = 0.0
    for _ in 0..<40 {
        try await Task.sleep(for: .milliseconds(100))
        pos = p.double("time-pos") ?? 0
        if pos > 0.5 { break }
    }
    #expect(pos > 0.5, "time-pos stayed at \(pos)")
    #expect(p.tracks().contains { $0.type == "video" })
    p.togglePause()
    try await Task.sleep(for: .milliseconds(300))
    #expect(p.flag("pause"))
}

@Test func endFileErrorIsReportedForUnplayableSource() async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null")
    nonisolated(unsafe) var sawError = false
    p.onEndFile = { isError in if isError { sawError = true } }
    p.load(URL(string: "file:///nonexistent/definitely-not-here.mkv")!, start: 0)
    for _ in 0..<40 where !sawError { try await Task.sleep(for: .milliseconds(100)) }
    #expect(sawError)
}
