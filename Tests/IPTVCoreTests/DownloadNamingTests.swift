import Testing
@testable import IPTVCore

@Test func downloadFileNamesAreSafeAndUnique() {
    #expect(DownloadNaming.fileName(title: "A/B: C?", ext: "MKV", taken: { _ in false }) == "A-B- C-.mkv")
    #expect(DownloadNaming.fileName(title: "  ..  ", ext: nil, taken: { _ in false }) == "download.mp4")
    #expect(DownloadNaming.fileName(title: "x", ext: "../../etc", taken: { _ in false }) == "x.mp4")
    #expect(DownloadNaming.fileName(title: "Movie", ext: "mp4", taken: { $0 == "Movie.mp4" || $0 == "Movie (2).mp4" }) == "Movie (3).mp4")
    #expect(DownloadNaming.fileName(title: String(repeating: "ש", count: 300), ext: "mp4", taken: { _ in false }).count == 124)
}
