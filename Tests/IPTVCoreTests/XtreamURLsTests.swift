import Testing
import Foundation
@testable import IPTVCore

@Test func normalizesMessyServerInput() {
    let u = XtreamURLs(server: "  example.com:8080/ ", username: "u", password: "p")!
    #expect(u.live(id: "12").absoluteString == "http://example.com:8080/live/u/p/12.ts")
    let https = XtreamURLs(server: "https://h.tv///", username: "u", password: "p")!
    #expect(https.movie(id: "3", ext: "mkv").absoluteString == "https://h.tv/movie/u/p/3.mkv")
    #expect(XtreamURLs(server: "   ", username: "u", password: "p") == nil)
}

@Test func credentialsWithSpecialCharactersArePercentEncoded() {
    let u = XtreamURLs(server: "h", username: "us er", password: "p@ss/w")!
    #expect(u.live(id: "1").absoluteString == "http://h/live/us%20er/p%40ss%2Fw/1.ts")
}

@Test func missingExtensionDefaults() {
    let u = XtreamURLs(server: "h", username: "u", password: "p")!
    #expect(u.movie(id: "1", ext: nil).absoluteString.hasSuffix("/1.mp4"))
    #expect(u.series(id: "1", ext: "").absoluteString.hasSuffix("/1.mp4"))
}

@Test func timeshiftFormat() {
    let u = XtreamURLs(server: "h", username: "u", password: "p")!
    let url = u.timeshift(id: "5", start: Date(timeIntervalSince1970: 1_700_000_000), minutes: 60,
                          timeZone: TimeZone(identifier: "UTC")!)
    #expect(url.absoluteString == "http://h/timeshift/u/p/60/2023-11-14:22-13/5.ts")
}

@Test func apiQueryEncodesReservedCharacters() {
    let u = XtreamURLs(server: "h", username: "u", password: "a&b+c")!
    #expect(u.api("get_live_streams").absoluteString ==
            "http://h/player_api.php?username=u&password=a%26b%2Bc&action=get_live_streams")
    #expect(u.api(nil).absoluteString == "http://h/player_api.php?username=u&password=a%26b%2Bc")
}
