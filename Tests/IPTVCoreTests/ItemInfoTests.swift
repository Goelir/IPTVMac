import Testing
import Foundation
import GRDB
@testable import IPTVCore

// What the provider says about a movie or series: tolerant parsing, and every value is untrusted.

/// A provider response (`{"info": {...}}`) as the untyped dictionary XtreamClient hands over.
func response(_ info: String) -> ItemInfo {
    let obj = try! JSONSerialization.jsonObject(with: Data(#"{"info":\#(info)}"#.utf8)) as! [String: Any]
    return ItemInfo(response: obj)
}

@Test func aTypicalMovieResponseIsParsed() {
    let i = response(#"""
        {"movie_image":"https://img.example.com/p.jpg","backdrop_path":["https://img.example.com/b1.jpg","https://img.example.com/b2.jpg"],
         "plot":"A heist goes wrong.","cast":"Ann, Bob","director":"Cy","genre":"Action, Crime","releasedate":"2019-05-24",
         "rating":"7.5","duration":"01:45:00","duration_secs":6300,"youtube_trailer":"dQw4w9WgXcQ","name":"The Heist","country":"US","age":"16"}
        """#)
    #expect(i.title == "The Heist"); #expect(i.plot == "A heist goes wrong."); #expect(i.cast == "Ann, Bob")
    #expect(i.director == "Cy"); #expect(i.genre == "Action, Crime"); #expect(i.country == "US")
    #expect(i.year == 2019); #expect(i.releaseDate == "2019-05-24"); #expect(i.rating == 7.5); #expect(i.durationMinutes == 105)
    #expect(i.trailerID == "dQw4w9WgXcQ")
    #expect(i.posterURL?.absoluteString == "https://img.example.com/p.jpg")
    #expect(i.backdropURL?.absoluteString == "https://img.example.com/b1.jpg")
    #expect(i.hasContent)
}

@Test func aSeriesResponseUsesItsOwnFieldNames() {
    let i = response(#"{"name":"The Show","cover":"https://c.example.com/s.jpg","plot":"Town secrets.","cast":"X","director":"Y","genre":"Drama","releaseDate":"2021-02-01","rating":"8.1","backdrop_path":[],"youtube_trailer":"","episode_run_time":"45"}"#)
    #expect(i.title == "The Show"); #expect(i.posterURL?.absoluteString == "https://c.example.com/s.jpg")
    #expect(i.year == 2021); #expect(i.rating == 8.1); #expect(i.durationMinutes == 45)
    #expect(i.backdropURL == nil); #expect(i.trailerID == nil)
}

@Test func numbersWhereStringsAreExpectedAreAccepted() {
    let i = response(#"{"plot":12345,"rating":7.5,"duration_secs":"6300","year":2018,"cast":["Ann","Bob"],"genre":["Action","Crime"]}"#)
    #expect(i.rating == 7.5); #expect(i.durationMinutes == 105); #expect(i.year == 2018)
    #expect(i.plot == "12345"); #expect(i.cast == "Ann, Bob"); #expect(i.genre == "Action, Crime")
}

@Test func nullsEmptyStringsAndEmptyArraysMeanNothingToShow() {
    let empty = response(#"{"plot":null,"cast":"","director":"  ","genre":[],"rating":"","backdrop_path":[],"movie_image":null,"youtube_trailer":null,"duration":"","releasedate":""}"#)
    #expect(!empty.hasContent)
    #expect(!response("[]").hasContent)                     // panels answer "info": [] for a title they know nothing about
    #expect(!response("null").hasContent)
    #expect(!response(#""oops""#).hasContent)
    #expect(!ItemInfo(response: [:]).hasContent)
    #expect(!ItemInfo().hasContent)
    #expect(response(#"{"plot":"x"}"#).hasContent)
}

@Test func aNameAloneIsNotDetails() {
    #expect(!response(#"{"name":"Only a name"}"#).hasContent)
}

@Test func backdropPathMayBeAnArrayAStringOrEmpty() {
    #expect(response(#"{"backdrop_path":["https://i.example.com/a.jpg"]}"#).backdropURL?.absoluteString == "https://i.example.com/a.jpg")
    #expect(response(#"{"backdrop_path":"https://i.example.com/b.jpg"}"#).backdropURL?.absoluteString == "https://i.example.com/b.jpg")
    #expect(response(#"{"backdrop_path":[]}"#).backdropURL == nil)
    #expect(response(#"{"backdrop_path":""}"#).backdropURL == nil)
    #expect(response(#"{"backdrop_path":null}"#).backdropURL == nil)
    #expect(response(#"{"backdrop_path":[null,"","http://192.168.1.1/x.jpg","https://i.example.com/c.jpg"]}"#).backdropURL?.absoluteString == "https://i.example.com/c.jpg")
}

@Test func releaseDatesInCommonFormatsGiveAYear() {
    let cases: [(String, Int?)] = [("2019-05-24", 2019), ("2019-05-24 00:00:00", 2019), ("24/05/2019", 2019), ("24.05.2019", 2019), ("2019", 2019),
                                   ("May 24, 2019", 2019), ("", nil), ("0000-00-00", nil), ("soon", nil), ("1558656000", nil), ("3019-01-01", nil)]
    for (s, year) in cases {
        #expect(response(#"{"releasedate":"\#(s)"}"#).year == year, "releasedate \(s)")
    }
    #expect(response(#"{"release_date":"2020-01-02"}"#).year == 2020)
    #expect(response(#"{"releaseDate":"2020-01-02"}"#).year == 2020)
    #expect(response(#"{"year":"1999"}"#).year == 1999)
    #expect(response(#"{"releasedate":"2019-05-24"}"#).releaseDate == "2019-05-24")
}

@Test func ratingsAreOnATenPointScale() {
    let cases: [(String, Double?)] = [(#""7.5""#, 7.5), ("7.5", 7.5), (#""0""#, nil), ("0", nil), (#""""#, nil), ("null", nil), (#""7,5""#, 7.5),
                                      (#""N/A""#, nil), (#""8.25""#, 8.3), ("10", 10), (#""85""#, 8.5), ("150", nil), ("-3", nil), (#""7.5/10""#, 7.5)]
    for (raw, want) in cases { #expect(response(#"{"rating":\#(raw)}"#).rating == want, "rating \(raw)") }
    #expect(response(#"{"rating":"0","rating_5based":"3.5"}"#).rating == 7)          // only the five-star value is filled
    #expect(response(#"{"rating":"8","rating_5based":"3.5"}"#).rating == 8)
}

@Test func durationsInTheFormsProvidersUse() {
    let cases: [(String, Int?)] = [(#""01:45:00""#, 105), ("6300", 105), (#""6300""#, 105), (#""105 min""#, 105), (#""1h 45m""#, 105), (#""2 hours""#, 120),
                                   (#""45""#, 45), (#""00:00:00""#, nil), (#""""#, nil), ("0", nil), ("9999999", nil), (#""soon""#, nil), (#""01:30""#, 90)]
    for (raw, want) in cases { #expect(response(#"{"duration":\#(raw)}"#).durationMinutes == want, "duration \(raw)") }
    #expect(response(#"{"duration":"00:00:00","duration_secs":5400}"#).durationMinutes == 90)       // seconds win over the text
    #expect(response(#"{"runtime":"100"}"#).durationMinutes == 100)
    #expect(response(#"{"episode_run_time":45}"#).durationMinutes == 45)
}

@Test func trailerIsAYouTubeIdAndNothingElse() {
    func trailer(_ s: String) -> String? { response(#"{"youtube_trailer":"\#(s)"}"#).trailerID }
    #expect(trailer("dQw4w9WgXcQ") == "dQw4w9WgXcQ")
    #expect(trailer("a_b-c_d-e12") == "a_b-c_d-e12")
    #expect(trailer("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
    #expect(trailer("https://youtu.be/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
    #expect(trailer("https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=5") == "dQw4w9WgXcQ")
    #expect(trailer("https://evil.example/watch?v=dQw4w9WgXcQ") == nil)          // not a YouTube host
    #expect(trailer("https://notyoutube.com/watch?v=dQw4w9WgXcQ") == nil)
    #expect(trailer("https://evil.example/dQw4w9WgXcQ") == nil)                  // a valid-looking id on a foreign host is still a foreign link
    #expect(trailer("https://www.youtube.com/user/dQw4w9WgXcQ") == nil)          // a YouTube page that is not a video
    #expect(trailer("javascript:alert(1)") == nil)
    #expect(trailer("file:///etc/passwd") == nil)
    #expect(trailer("abc") == nil)                                               // too short
    #expect(trailer(String(repeating: "a", count: 21)) == nil)                    // too long
    #expect(trailer("dQw4w9WgXcQ&x=<script>") == nil)
    #expect(trailer("dQw4w9 WgXcQ") == nil)
    #expect(trailer("") == nil)
}

@Test func theTrailerLinkIsBuiltByUsFromTheValidatedId() {
    #expect(response(#"{"youtube_trailer":"https://youtu.be/dQw4w9WgXcQ?x=http://evil"}"#).trailerURL?.absoluteString == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    var i = ItemInfo(); i.trailerID = "dQw4w9WgXcQ"
    #expect(i.trailerURL?.absoluteString == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    i.trailerID = "x/../../evil"                                                  // a tampered cache row
    #expect(i.trailerURL == nil)
    i.trailerID = nil
    #expect(i.trailerURL == nil)
}

@Test func hostileTextIsCappedAndStaysPlainText() {
    let plot = String(repeating: "a", count: 100_000)
    let i = response(#"{"plot":"\#(plot)","cast":"\#(String(repeating: "b", count: 5000))","director":"\#(String(repeating: "c", count: 5000))","genre":"\#(String(repeating: "g", count: 5000))","name":"\#(String(repeating: "n", count: 5000))","country":"\#(String(repeating: "k", count: 5000))"}"#)
    #expect(i.plot!.count <= 4000 && i.plot!.count > 3000)
    #expect(i.cast!.count <= 500); #expect(i.director!.count <= 200); #expect(i.genre!.count <= 200)
    #expect(i.title!.count <= 300); #expect(i.country!.count <= 100)

    let html = #"<script>alert(1)</script> <b>bold</b> **md** [click](https://evil.example) https://evil.example/x"#
    #expect(response(#"{"plot":"\#(html.replacingOccurrences(of: "\"", with: "\\\""))"}"#).plot == html)   // kept as typed: shown verbatim, never interpreted

    let tricky = response(#"{"plot":"line1\nline2\u0000‮evil⁩\tend\n\n\n\n\nlast"}"#).plot
    #expect(tricky == "line1\nline2evil\tend\n\nlast")                            // control and bidi-override characters dropped, blank runs shortened
}

@Test func imageUrlsFromTheProviderMustBeSafe() {
    func poster(_ s: String) -> URL? { response(#"{"movie_image":"\#(s)"}"#).posterURL }
    #expect(poster("https://cdn.example.com/p.jpg") != nil)
    #expect(poster("http://cdn.example.com/p.jpg") != nil)
    #expect(poster("http://192.168.1.1/cgi-bin/reboot") == nil)
    #expect(poster("http://10.0.0.5/p.jpg") == nil)
    #expect(poster("http://localhost:8123/api/webhook/x") == nil)
    #expect(poster("http://printer.local/p.jpg") == nil)
    #expect(poster("http://[::1]/p.jpg") == nil)
    #expect(poster("file:///etc/passwd") == nil)
    #expect(poster("data:image/png;base64,AAAA") == nil)
    #expect(poster("javascript:alert(1)") == nil)
    #expect(poster("ftp://cdn.example.com/p.jpg") == nil)
    #expect(response(#"{"cover_big":"https://cdn.example.com/big.jpg"}"#).posterURL != nil)          // other poster fields work too
    #expect(response(#"{"movie_image":"http://10.0.0.5/x","cover_big":"https://cdn.example.com/big.jpg"}"#).posterURL?.host == "cdn.example.com")
}

@Test func theSharedImageCheckBehindItemIconURLIsTheSameOne() {
    #expect(RemoteImage.safeURL("https://cdn.example.com/a.png") != nil)
    #expect(RemoteImage.safeURL(" https://cdn.example.com/a.png \n") != nil)
    #expect(RemoteImage.safeURL("http://192.168.0.9/a.png") == nil)
    #expect(RemoteImage.safeURL(nil) == nil)
    #expect(RemoteImage.safeURL("") == nil)
    #expect(Item(accountId: 1, type: .movie, name: "x", streamId: "1", icon: "http://172.16.0.1/a.png").iconURL == nil)
}

@Test func itemInfoSurvivesTheJSONRoundTripUsedByTheCache() throws {
    let i = response(#"{"movie_image":"https://img.example.com/p.jpg","plot":"p","rating":"6.5","duration":"90","releasedate":"2001-01-01","youtube_trailer":"dQw4w9WgXcQ"}"#)
    let back = try JSONDecoder().decode(ItemInfo.self, from: JSONEncoder().encode(i))
    #expect(back == i)
    #expect(try JSONDecoder().decode(ItemInfo.self, from: Data("{}".utf8)) == ItemInfo())   // a row from an older version with fewer fields
}
