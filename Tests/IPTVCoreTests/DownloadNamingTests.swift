import Testing
@testable import IPTVCore

@Test func downloadFileNamesAreSafeAndUnique() {
    #expect(DownloadNaming.fileName(title: "A/B: C?", ext: "MKV", taken: { _ in false }) == "A-B- C-.mkv")
    #expect(DownloadNaming.fileName(title: "  ..  ", ext: nil, taken: { _ in false }) == "download.mp4")
    #expect(DownloadNaming.fileName(title: "x", ext: "../../etc", taken: { _ in false }) == "x.mp4")
    #expect(DownloadNaming.fileName(title: "Movie", ext: "mp4", taken: { $0 == "Movie.mp4" || $0 == "Movie (2).mp4" }) == "Movie (3).mp4")
    let long = DownloadNaming.fileName(title: String(repeating: "ש", count: 300), ext: "mp4", taken: { _ in false })
    #expect(long.utf8.count <= 250 && long.hasSuffix(".mp4"))   // 255 bytes is the file-system limit, Hebrew/CJK/emoji take 2-4 bytes
    #expect(DownloadNaming.fileName(title: "x", ext: "dmg", taken: { _ in false }) == "x.mp4")   // the provider must not choose .dmg/.pkg/.app
    #expect(DownloadNaming.fileName(title: "x", ext: "MKV", taken: { _ in false }) == "x.mkv")
}
