import Foundation
import CryptoKit

public func sha256Hex(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

public enum UpdateError: Error, LocalizedError, Equatable {
    case checksumMismatch, badApp(String), installFailed(String)
    public var errorDescription: String? {
        switch self {
        case .checksumMismatch: return "The downloaded update is corrupted (checksum mismatch)"
        case .badApp(let m): return "The downloaded update is not valid: \(m)"
        case .installFailed(let m): return "Could not install the update: \(m)"
        }
    }
}

/// Dotted numeric version ("v0.2.0", "1.0"), compared component by component.
public struct SemVer: Comparable, Equatable {
    private let parts: [Int]
    public init?(_ s: String) {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("v") || t.hasPrefix("V") { t.removeFirst() }
        let comps = t.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !comps.isEmpty, comps.count <= 4, !comps.contains(where: { $0 == nil || $0! < 0 }) else { return nil }
        parts = comps.map { $0! } + Array(repeating: 0, count: 4 - comps.count)
    }
    public static func < (a: SemVer, b: SemVer) -> Bool { a.parts.lexicographicallyPrecedes(b.parts) }
}

public struct AppUpdate: Equatable {
    public var version: String
    public var notes: String
    public var dmgURL: URL
    public var sha256: String
    public var pageURL: URL?
    public init(version: String, notes: String, dmgURL: URL, sha256: String, pageURL: URL? = nil) {
        self.version = version; self.notes = notes; self.dmgURL = dmgURL; self.sha256 = sha256; self.pageURL = pageURL
    }
}

public enum UpdateChecker {
    public static let repo = "Goelir/IPTVMac"
    public static let assetName = "IPTVMac.dmg"
    /// scripts/release.sh writes exactly this line into the release notes; the app only installs what it can verify with it.
    static let shaRegex = try! NSRegularExpression(pattern: "SHA-256 of IPTVMac\\.dmg:\\s*`([0-9a-fA-F]{64})`")

    /// A release the app may install: published, has a version tag, an IPTVMac.dmg asset and a published checksum.
    public static func parse(releaseJSON: Data) -> AppUpdate? {
        guard let o = try? JSONSerialization.jsonObject(with: releaseJSON) as? [String: Any],
              (o["draft"] as? Bool) != true, (o["prerelease"] as? Bool) != true,
              let tag = o["tag_name"] as? String, SemVer(tag) != nil,
              let assets = o["assets"] as? [[String: Any]],
              let dmg = assets.first(where: { ($0["name"] as? String) == assetName }),
              let urlStr = dmg["browser_download_url"] as? String, let url = URL(string: urlStr),
              url.scheme == "https",
              let body = o["body"] as? String
        else { return nil }
        let ns = body as NSString
        guard let m = shaRegex.firstMatch(in: body, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let sha = ns.substring(with: m.range(at: 1)).lowercased()
        let notes = ns.substring(to: m.range.location).trimmingCharacters(in: .whitespacesAndNewlines)
        let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        return AppUpdate(version: version, notes: notes, dmgURL: url, sha256: sha, pageURL: (o["html_url"] as? String).flatMap(URL.init))
    }

    /// The latest release if it is newer than `current`; nil when up to date or when `current` is not a version.
    public static func check(current: String, session: URLSession = apiSession, repo: String = repo) async throws -> AppUpdate? {
        guard let cur = SemVer(current), let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("IPTVMac", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        if let code = (resp as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) { throw IPTVError.http(code) }
        guard let u = parse(releaseJSON: data), let v = SemVer(u.version), v > cur else { return nil }
        return u
    }

    /// Downloads the DMG and verifies its SHA-256; returns a temp file path. Throws `.checksumMismatch` on any difference.
    // ponytail: the whole ~15 MB DMG is held in memory; switch to a file download with incremental hashing if it grows a lot.
    public static func downloadDMG(_ u: AppUpdate, session: URLSession = apiSession) async throws -> URL {
        let (data, resp) = try await session.data(from: u.dmgURL)
        if let code = (resp as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) { throw IPTVError.http(code) }
        guard sha256Hex(data) == u.sha256.lowercased() else { throw UpdateError.checksumMismatch }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("IPTVMac-\(u.version)-\(UUID().uuidString).dmg")
        try data.write(to: file)
        return file
    }
}

public enum UpdateInstaller {
    @discardableResult
    static func tool(_ path: String, _ args: [String]) throws -> (status: Int32, output: String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        try p.run()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        return (p.terminationStatus, out)
    }

    /// Mounts the DMG, copies IPTVMac.app into `dir`, and checks its version and code signature. Always unmounts.
    public static func stage(dmg: URL, expectedVersion: String, into dir: URL) throws -> URL {
        let fm = FileManager.default
        let mnt = fm.temporaryDirectory.appendingPathComponent("iptvmac-mnt-\(UUID().uuidString)")
        try fm.createDirectory(at: mnt, withIntermediateDirectories: true)
        let attach = try tool("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noverify", "-noautoopen", "-mountpoint", mnt.path, dmg.path])
        guard attach.status == 0 else { try? fm.removeItem(at: mnt); throw UpdateError.badApp("cannot open the disk image") }
        defer { _ = try? tool("/usr/bin/hdiutil", ["detach", "-force", mnt.path]); try? fm.removeItem(at: mnt) }

        let src = mnt.appendingPathComponent("IPTVMac.app")
        guard fm.fileExists(atPath: src.path) else { throw UpdateError.badApp("IPTVMac.app is not in the disk image") }
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("IPTVMac.app")
        try? fm.removeItem(at: dest)
        guard try tool("/usr/bin/ditto", [src.path, dest.path]).status == 0 else { throw UpdateError.installFailed("copy failed") }

        func reject(_ m: String) -> UpdateError { try? fm.removeItem(at: dest); return .badApp(m) }
        let plist = NSDictionary(contentsOf: dest.appendingPathComponent("Contents/Info.plist"))
        guard let v = plist?["CFBundleShortVersionString"] as? String, SemVer(v) == SemVer(expectedVersion), SemVer(v) != nil
        else { throw reject("version is not \(expectedVersion)") }
        guard try tool("/usr/bin/codesign", ["--verify", "--deep", "--strict", dest.path]).status == 0 else { throw reject("signature is broken") }
        return dest
    }

    /// Starts a detached shell that waits for process `pid` to exit, swaps `staged` in place of `target` (keeping the old
    /// app if anything fails), clears quarantine, and optionally relaunches. Returns the shell process.
    @discardableResult
    public static func scheduleSwap(pid: Int32, target: URL, staged: URL, relaunch: Bool) throws -> Process {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.3; done
        [ -d "$3" ] || exit 1
        BAK="$2.old.$$"
        mv "$2" "$BAK" || exit 1
        if ! mv "$3" "$2"; then mv "$BAK" "$2"; exit 1; fi
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        rm -rf "$BAK"
        [ "$4" = "1" ] && open "$2"
        exit 0
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, "sh", String(pid), target.path, staged.path, relaunch ? "1" : "0"]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run()
        return p
    }
}
