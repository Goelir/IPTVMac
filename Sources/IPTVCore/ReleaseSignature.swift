import Foundation
import CryptoKit

/// Release signatures made with `ssh-keygen -Y sign` (SSHSIG, Ed25519). The release notes carry the signature of
/// "iptvmac-release\n<tag>\n<sha256 of IPTVMac.dmg>\n"; the app and install.sh trust only this key, not the GitHub account.
/// The private key lives outside GitHub (see scripts/release.sh), so a stolen GitHub token cannot produce an installable update.
public enum ReleaseSignature {
    public static let namespace = "iptvmac-release"
    /// scripts/release-key.pub: the ssh wire format of the public key (type + 32 raw bytes), base64.
    public static let publicKeyBlob = "AAAAC3NzaC1lZDI1NTE5AAAAIPYoXjKoZvOnw2h3ks4sAtdmjORMoYFi/2WOuO8q13sh"

    public static func message(tag: String, sha256: String) -> Data {
        Data("\(namespace)\n\(tag)\n\(sha256.lowercased())\n".utf8)
    }

    /// `Signature: `<base64 of the SSHSIG blob>`` line of the release notes.
    static let lineRegex = try! NSRegularExpression(pattern: "Signature:\\s*`([A-Za-z0-9+/=]{100,})`")
    public static func extract(from notes: String) -> String? {
        let ns = notes as NSString
        guard let m = lineRegex.firstMatch(in: notes, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    private struct Reader {
        let d: Data; var i = 0
        mutating func bytes(_ n: Int) -> Data? { guard n >= 0, i + n <= d.count else { return nil }; defer { i += n }; return d.subdata(in: i..<i + n) }
        mutating func u32() -> Int? { bytes(4).map { $0.reduce(0) { ($0 << 8) | Int($1) } } }
        mutating func string() -> Data? { u32().flatMap { bytes($0) } }
    }
    private static func ssh(_ s: Data) -> Data { var d = Data(); let n = UInt32(s.count); d += [UInt8(n >> 24), UInt8((n >> 16) & 255), UInt8((n >> 8) & 255), UInt8(n & 255)]; return d + s }

    /// The 32 raw key bytes of an ssh-ed25519 public key blob (type string + key string), nil if malformed.
    static func rawKey(fromBlob blob: Data) -> Data? {
        var r = Reader(d: blob)
        guard let t = r.string(), String(decoding: t, as: UTF8.self) == "ssh-ed25519", let k = r.string(), k.count == 32 else { return nil }
        return k
    }

    /// True only if `signatureBase64` is a valid SSHSIG over `message` made by the trusted key in our namespace.
    public static func verify(signatureBase64: String, message: Data, trustedBlobBase64: String = publicKeyBlob) -> Bool {
        guard let sig = Data(base64Encoded: signatureBase64), let trustedBlob = Data(base64Encoded: trustedBlobBase64),
              let trustedKey = rawKey(fromBlob: trustedBlob) else { return false }
        var r = Reader(d: sig)
        guard r.bytes(6).map({ String(decoding: $0, as: UTF8.self) }) == "SSHSIG", r.u32() == 1,
              let pubBlob = r.string(), let ns = r.string(), let reserved = r.string(), let hashAlg = r.string(), let sigBlob = r.string(),
              r.i == sig.count,                                                   // nothing after the signature
              rawKey(fromBlob: pubBlob) == trustedKey,                            // signed by OUR key, whatever key the blob claims
              String(decoding: ns, as: UTF8.self) == namespace else { return false }
        let digest: Data
        switch String(decoding: hashAlg, as: UTF8.self) {
        case "sha512": digest = Data(SHA512.hash(data: message))
        case "sha256": digest = Data(SHA256.hash(data: message))
        default: return false
        }
        var sr = Reader(d: sigBlob)
        guard let st = sr.string(), String(decoding: st, as: UTF8.self) == "ssh-ed25519", let raw = sr.string(), raw.count == 64 else { return false }
        let signed = Data("SSHSIG".utf8) + ssh(ns) + ssh(reserved) + ssh(hashAlg) + ssh(digest)
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: trustedKey) else { return false }
        return key.isValidSignature(raw, for: signed)
    }
}
