import Testing
@testable import IPTVCore

@Test func parsesAttributesAndName() {
    var p = M3UParser()
    #expect(p.feed("#EXTM3U") == nil)
    #expect(p.feed(#"#EXTINF:-1 tvg-id="a.b" tvg-logo="http://x/l.png" group-title="News",Channel One"#) == nil)
    let e = p.feed("http://h/live/1.ts")
    #expect(e == M3UEntry(name: "Channel One", url: "http://h/live/1.ts", group: "News",
                          logo: "http://x/l.png", tvgId: "a.b", catchupDays: nil))
}

@Test func toleratesBOMCRLFAndMissingAttributes() {
    var p = M3UParser()
    #expect(p.feed("\u{FEFF}#EXTM3U\r") == nil)
    #expect(p.feed("#EXTINF:-1,Plain\r") == nil)
    let e = p.feed("http://h/a\r")
    #expect(e?.name == "Plain"); #expect(e?.group == nil); #expect(e?.url == "http://h/a")
}

@Test func commaInsideQuotedAttributeDoesNotSplitName() {
    var p = M3UParser()
    _ = p.feed(#"#EXTINF:-1 group-title="A, B",Name, Part2"#)
    let e = p.feed("http://h/a")
    #expect(e?.group == "A, B"); #expect(e?.name == "Name, Part2")
}

@Test func ignoresOtherDirectivesAndBlankLines() {
    var p = M3UParser()
    _ = p.feed("#EXTINF:-1,X")
    #expect(p.feed("#EXTVLCOPT:http-user-agent=foo") == nil)
    #expect(p.feed("") == nil)
    #expect(p.feed("http://h/x")?.name == "X")
}

@Test func urlWithoutExtinfUsesLastPathComponentAsName() {
    var p = M3UParser()
    #expect(p.feed("http://h/path/movie.mkv")?.name == "movie.mkv")
}

@Test func catchupDaysAreParsed() {
    var p = M3UParser()
    _ = p.feed(#"#EXTINF:-1 catchup-days="3",Y"#)
    #expect(p.feed("http://h/y")?.catchupDays == 3)
}

@Test func classifierUsesPathThenGroupThenExtension() {
    #expect(M3UClassifier.type(url: "http://h/movie/u/p/1.mkv", group: nil) == .movie)
    #expect(M3UClassifier.type(url: "http://h/series/u/p/1.mkv", group: nil) == .series)
    #expect(M3UClassifier.type(url: "http://h/1.ts", group: "VOD Action") == .movie)
    #expect(M3UClassifier.type(url: "http://h/1.ts", group: "סדרות ישראליות") == .series)
    #expect(M3UClassifier.type(url: "http://h/1.mp4", group: nil) == .movie)
    #expect(M3UClassifier.type(url: "http://h/1.ts", group: "News") == .live)
}
