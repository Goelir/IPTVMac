import Testing
import Foundation
@testable import IPTVPlayer

@Test func videoScaleMapsToThePanscanAndKeepAspectProperties() {
    #expect(VideoScale.fit.panscan == 0 && VideoScale.fit.keepAspect)
    #expect(VideoScale.fill.panscan == 1 && VideoScale.fill.keepAspect)
    #expect(VideoScale.stretch.panscan == 0 && !VideoScale.stretch.keepAspect)
}

@Test func videoScaleRawValuesAreTheStoredPreference() {
    #expect(VideoScale.allCases.map(\.rawValue) == ["fit", "fill", "stretch"])
    #expect(VideoScale(rawValue: "fill") == .fill)
    #expect(VideoScale(rawValue: "nonsense") == nil)
}

@Test func videoScaleCyclesThroughAllThreeAndComesBack() {
    #expect(VideoScale.fit.next == .fill)
    #expect(VideoScale.fill.next == .stretch)
    #expect(VideoScale.stretch.next == .fit)
}

@Test func bufferSizesGrowAndNormalIsTodaysSetting() {
    let b = BufferSize.allCases
    #expect(b.map(\.rawValue) == ["small", "normal", "large"])
    #expect(b.map(\.maxBytes) == b.map(\.maxBytes).sorted() && Set(b.map(\.maxBytes)).count == 3)
    #expect(b.map(\.readaheadSecs) == b.map(\.readaheadSecs).sorted() && Set(b.map(\.readaheadSecs)).count == 3)
    #expect(BufferSize.normal.maxBytes == 64 << 20 && BufferSize.normal.readaheadSecs == 20)
    #expect(BufferSize(rawValue: "huge") == nil)
}

/// Real libmpv: the properties the app sets must exist, accept the values at runtime and read back unchanged.
@Test(arguments: VideoScale.allCases)
func videoScalePropertiesReadBackFromTheEngine(_ s: VideoScale) {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("panscan", "0.5"); p.setProperty("keepaspect", "no")   // a different state first
    p.apply(s)
    #expect(p.double("panscan") == s.panscan)
    #expect(p.flag("keepaspect") == s.keepAspect)
}

@Test func engineStartsWithTheFitScale() {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    #expect(p.double("panscan") == VideoScale.fit.panscan)
    #expect(p.flag("keepaspect") == VideoScale.fit.keepAspect)
}

@Test func videoScaleCanChangeWhileAFileIsLoaded() async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.setProperty("vo", "null"); p.setProperty("ao", "null")
    p.load(testVideo, start: 0)
    for _ in 0..<40 where (p.double("time-pos") ?? 0) < 0.3 { try await Task.sleep(for: .milliseconds(100)) }
    for s in [VideoScale.fill, .stretch, .fit] {
        p.apply(s)
        #expect(p.double("panscan") == s.panscan && p.flag("keepaspect") == s.keepAspect, "\(s)")
    }
}

@Test(arguments: BufferSize.allCases)
func bufferPropertiesReadBackFromTheEngine(_ b: BufferSize) {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    p.apply(b)
    #expect(p.double("demuxer-max-bytes") == Double(b.maxBytes))
    #expect(p.double("demuxer-readahead-secs") == Double(b.readaheadSecs))
}

@Test func engineStartsWithTheNormalBufferAndCanChangeWhilePlaying() async throws {
    let p = MPVPlayer(subLang: nil, audioLang: nil)
    defer { p.shutdown() }
    #expect(p.double("demuxer-max-bytes") == Double(BufferSize.normal.maxBytes))
    #expect(p.double("demuxer-readahead-secs") == Double(BufferSize.normal.readaheadSecs))
    p.setProperty("vo", "null"); p.setProperty("ao", "null")
    p.load(testVideo, start: 0)
    for _ in 0..<40 where (p.double("time-pos") ?? 0) < 0.3 { try await Task.sleep(for: .milliseconds(100)) }
    p.apply(BufferSize.large)
    #expect(p.double("demuxer-max-bytes") == Double(BufferSize.large.maxBytes))
    #expect(p.double("demuxer-readahead-secs") == Double(BufferSize.large.readaheadSecs))
    #expect((p.double("time-pos") ?? 0) > 0, "playback goes on after the change")
}
