import Foundation
import IPTVPlayer

/// `IPTVMac --selftest`: plays a generated 3 s silent WAV with the bundled libmpv and exits 0 on success.
/// Proves the shipped engine loads, opens a file and advances its clock on this Mac, without a stream or a window.
enum SelfTest {
    static func run() -> Never {
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-selftest-\(UUID().uuidString).wav")
        try? silentWAV(seconds: 3).write(to: wav)
        defer { try? FileManager.default.removeItem(at: wav) }
        let p = MPVPlayer(subLang: nil, audioLang: nil)
        p.setProperty("vo", "null")
        p.load(wav.path, start: 0)
        var pos = 0.0
        for _ in 0..<50 {
            Thread.sleep(forTimeInterval: 0.1)
            pos = p.double("time-pos") ?? 0
            if pos > 0.5 { break }
        }
        print("selftest: \(p.string("mpv-version") ?? "unknown") time-pos=\(pos)")
        p.shutdown()
        exit(pos > 0.5 ? 0 : 1)
    }

    /// 8 kHz mono 16-bit PCM silence.
    static func silentWAV(seconds: Int) -> Data {
        let rate = 8000, dataBytes = rate * seconds * 2
        func le32(_ v: Int) -> Data { withUnsafeBytes(of: UInt32(v).littleEndian) { Data($0) } }
        func le16(_ v: Int) -> Data { withUnsafeBytes(of: UInt16(v).littleEndian) { Data($0) } }
        var d = Data("RIFF".utf8); d += le32(36 + dataBytes); d += Data("WAVEfmt ".utf8)
        d += le32(16); d += le16(1); d += le16(1); d += le32(rate); d += le32(rate * 2); d += le16(2); d += le16(16)
        d += Data("data".utf8); d += le32(dataBytes); d += Data(count: dataBytes)
        return d
    }
}
