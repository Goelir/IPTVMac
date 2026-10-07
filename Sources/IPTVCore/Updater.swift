import Foundation
import CryptoKit

public func sha256Hex(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

public enum UpdateError: Error, LocalizedError, Equatable {
    case checksumMismatch, badApp(String), installFailed(String), tooLarge, rateLimited
    public var errorDescription: String? {
        switch self {
        case .checksumMismatch: return "The downloaded update is corrupted (checksum mismatch)"
        case .badApp(let m): return "The downloaded update is not valid: \(m)"
        case .installFailed(let m): return "Could not install the update: \(m)"
        case .tooLarge: return "The update is larger than expected"
        case .rateLimited: return "GitHub is limiting requests from this network. Try again in an hour, or download the update from the releases page."
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
    /// `trustedKeyBlob` / `repo` are parameters for tests; the app always uses the pinned key and repository.
    public static func parse(releaseJSON: Data, trustedKeyBlob: String = ReleaseSignature.publicKeyBlob, repo: String = repo) -> AppUpdate? {
        guard let o = try? JSONSerialization.jsonObject(with: releaseJSON) as? [String: Any],
              (o["draft"] as? Bool) != true, (o["prerelease"] as? Bool) != true,
              let tag = o["tag_name"] as? String, SemVer(tag) != nil,
              let assets = o["assets"] as? [[String: Any]],
              let dmg = assets.first(where: { ($0["name"] as? String) == assetName }),
              let urlStr = dmg["browser_download_url"] as? String, let url = URL(string: urlStr),
              url.scheme == "https", url.host?.lowercased() == "github.com", url.path.hasPrefix("/\(repo)/releases/download/"),
              let body = o["body"] as? String
        else { return nil }
        let ns = body as NSString
        guard let m = shaRegex.firstMatch(in: body, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let sha = ns.substring(with: m.range(at: 1)).lowercased()
        // The checksum alone only proves the download is intact: whoever controls the release can edit both. The signature
        // (made off GitHub, with a key pinned in this app) is what proves the release is ours.
        guard let sig = ReleaseSignature.extract(from: body),
              ReleaseSignature.verify(signatureBase64: sig, message: ReleaseSignature.message(tag: tag, sha256: sha), trustedBlobBase64: trustedKeyBlob)
        else { return nil }
        let notes = ns.substring(to: m.range.location).trimmingCharacters(in: .whitespacesAndNewlines)
        let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        let page = (o["html_url"] as? String).flatMap(URL.init).flatMap { $0.scheme == "https" && $0.host?.lowercased() == "github.com" ? $0 : nil }
        return AppUpdate(version: version, notes: notes, dmgURL: url, sha256: sha, pageURL: page)
    }

    /// scripts/release.sh attaches `release.txt` to every release: `tag=`, `sha256=` and `signature=` lines (the same signed
    /// message as the release notes). It is read from github.com, which has no API rate limit (60 requests an hour per IP).
    public static let manifestName = "release.txt"

    /// An update from `release.txt`; the DMG address is built from the signed tag, never taken from the file.
    public static func parse(manifest: Data, trustedKeyBlob: String = ReleaseSignature.publicKeyBlob, repo: String = repo) -> AppUpdate? {
        guard manifest.count < 4096, let text = String(data: manifest, encoding: .utf8) else { return nil }
        var f: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let eq = line.firstIndex(of: "=") else { continue }
            f[String(line[..<eq])] = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        }
        guard let tag = f["tag"], tag.range(of: "^v?[0-9]+(\\.[0-9]+){0,3}$", options: .regularExpression) != nil, SemVer(tag) != nil,
              let sha = f["sha256"]?.lowercased(), sha.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
              let sig = f["signature"],
              ReleaseSignature.verify(signatureBase64: sig, message: ReleaseSignature.message(tag: tag, sha256: sha), trustedBlobBase64: trustedKeyBlob),
              let dmg = URL(string: "https://github.com/\(repo)/releases/download/\(tag)/\(assetName)"),
              let page = URL(string: "https://github.com/\(repo)/releases/tag/\(tag)")
        else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return AppUpdate(version: version, notes: "", dmgURL: dmg, sha256: sha, pageURL: page)
    }

    /// The latest release if it is newer than `current`; nil when up to date or when `current` is not a version.
    /// Looks at `release.txt` first (no rate limit); releases without it, and any failure there, fall back to the GitHub API.
    public static func check(current: String, session: URLSession = apiSession, repo: String = repo,
                             trustedKeyBlob: String = ReleaseSignature.publicKeyBlob) async throws -> AppUpdate? {
        guard let cur = SemVer(current), let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest"),
              let manifestURL = URL(string: "https://github.com/\(repo)/releases/latest/download/\(manifestName)") else { return nil }
        var mreq = URLRequest(url: manifestURL)
        mreq.setValue("IPTVMac", forHTTPHeaderField: "User-Agent")
        if let (data, resp) = try? await session.data(for: mreq), (resp as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
           let u = parse(manifest: data, trustedKeyBlob: trustedKeyBlob, repo: repo) {
            if let v = SemVer(u.version), v > cur { return u }
            return nil
        }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("IPTVMac", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        if let code = (resp as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) {
            throw code == 403 || code == 429 ? UpdateError.rateLimited : IPTVError.http(code)
        }
        guard let u = parse(releaseJSON: data, trustedKeyBlob: trustedKeyBlob, repo: repo), let v = SemVer(u.version), v > cur else { return nil }
        return u
    }

    /// Refuses redirects that leave HTTPS (credentials are not involved, but a plain-http hop would let anyone on the path swap the file).
    private final class HTTPSOnly: NSObject, URLSessionTaskDelegate {
        func urlSession(_ s: URLSession, task: URLSessionTask, willPerformHTTPRedirection r: HTTPURLResponse, newRequest req: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(req.url?.scheme?.lowercased() == "https" ? req : nil)
        }
    }

    static let maxDMGBytes = 120_000_000

    /// Downloads the DMG (size-capped) and verifies its SHA-256; returns a temp file path. Throws `.checksumMismatch` on any difference.
    /// The checksum itself is covered by the release signature (see `parse`).
    // ponytail: the whole ~15 MB DMG is held in memory; switch to a file download with incremental hashing if it grows a lot.
    public static func downloadDMG(_ u: AppUpdate, session: URLSession? = nil) async throws -> URL {
        let s = session ?? URLSession(configuration: .ephemeral, delegate: HTTPSOnly(), delegateQueue: nil)
        let (bytes, resp) = try await s.bytes(from: u.dmgURL)
        if let code = (resp as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) { throw IPTVError.http(code) }
        if resp.expectedContentLength > Int64(maxDMGBytes) { throw UpdateError.tooLarge }
        var data = Data()
        data.reserveCapacity(max(0, min(Int(resp.expectedContentLength), maxDMGBytes)))
        for try await b in bytes {
            data.append(b)
            if data.count > maxDMGBytes { throw UpdateError.tooLarge }
        }
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
    /// `expectedBundleID` / `currentVersion` are checked when given (the app passes its own): a different app, or an older one, is refused.
    public static func stage(dmg: URL, expectedVersion: String, into dir: URL, expectedBundleID: String? = nil, currentVersion: String? = nil) throws -> URL {
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
        if let cur = currentVersion.flatMap(SemVer.init), let new = SemVer(v), new <= cur { throw reject("version \(v) is not newer than the installed one") }
        if let id = expectedBundleID, plist?["CFBundleIdentifier"] as? String != id { throw reject("it is a different application") }
        guard plist?["CFBundleExecutable"] as? String == "IPTVMac" else { throw reject("unexpected executable") }
        guard try tool("/usr/bin/codesign", ["--verify", "--deep", "--strict", dest.path]).status == 0 else { throw reject("signature is broken") }
        return dest
    }

    /// Starts a detached shell that waits for process `pid` to exit, swaps `staged` in place of `target` (keeping the old
    /// app if anything fails), clears quarantine, and optionally relaunches. Returns the shell process.
    @discardableResult
    public static func scheduleSwap(pid: Int32, target: URL, staged: URL, relaunch: Bool) throws -> Process {
        // The new copy is made INSIDE the target's folder first, so the final swap is two same-volume renames (atomic), never a
        // copy+delete across volumes that a failure could leave half done. Waits at most 60 s for the old process (a reused pid
        // must not block the update forever).
        let script = """
        n=0
        while kill -0 "$1" 2>/dev/null && [ "$n" -lt 200 ]; do sleep 0.3; n=$((n+1)); done
        [ -d "$3" ] || exit 1
        NEW="$(dirname "$2")/.IPTVMac.new.$$"
        BAK="$2.old.$$"
        rm -rf "$NEW"
        /usr/bin/ditto "$3" "$NEW" || { rm -rf "$NEW"; exit 1; }
        mv "$2" "$BAK" || { rm -rf "$NEW"; exit 1; }
        if ! mv "$NEW" "$2"; then mv "$BAK" "$2"; rm -rf "$NEW"; exit 1; fi
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        rm -rf "$BAK" "$3"
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
