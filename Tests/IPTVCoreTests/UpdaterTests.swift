import Testing
import Foundation
@testable import IPTVCore

// MARK: pure logic

@Test func semverOrdersNumerically() {
    #expect(SemVer("v0.2.0")! > SemVer("0.1.2")!)
    #expect(SemVer("0.10.0")! > SemVer("0.9.9")!)
    #expect(SemVer("1.0")! == SemVer("1.0.0")!)
    #expect(SemVer("0.1")! < SemVer("0.1.1")!)
    #expect(SemVer("") == nil); #expect(SemVer("abc") == nil); #expect(SemVer("1.x.0") == nil)
}

/// A throw-away signing key made by the real ssh-keygen, the same tool scripts/release.sh uses.
private struct TestSigner {
    let dir: URL, keyPath: String, blob: String
    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        keyPath = dir.appendingPathComponent("k").path
        try run("/usr/bin/ssh-keygen", ["-q", "-t", "ed25519", "-N", "", "-f", keyPath])
        let pub = try String(contentsOfFile: keyPath + ".pub", encoding: .utf8).split(separator: " ")
        blob = String(pub[1])
    }
    func sign(_ message: Data, namespace: String = "iptvmac-release") throws -> String {
        let f = dir.appendingPathComponent("m-\(UUID().uuidString)")
        try message.write(to: f)
        try run("/usr/bin/ssh-keygen", ["-Y", "sign", "-q", "-f", keyPath, "-n", namespace, f.path])
        let armored = try String(contentsOfFile: f.path + ".sig", encoding: .utf8)
        return armored.split(separator: "\n").filter { !$0.hasPrefix("-----") }.joined()
    }
}
private let signer = try! TestSigner()

private func releaseJSON(tag: String = "v0.2.0", draft: Bool = false, pre: Bool = false, sha: String? = String(repeating: "a", count: 64),
                         asset: String = "IPTVMac.dmg", signed: Bool = true, signWith: TestSigner = signer, signTag: String? = nil,
                         host: String = "github.com", path: String = "o/r") -> Data {
    var body = "Notes here.\\n\\n" + (sha.map { "SHA-256 of IPTVMac.dmg: `\($0)`" } ?? "no checksum")
    if signed, let sha, let sig = try? signWith.sign(ReleaseSignature.message(tag: signTag ?? tag, sha256: sha)) { body += "\\nSignature: `\(sig)`" }
    return Data("""
    {"tag_name":"\(tag)","draft":\(draft),"prerelease":\(pre),"body":"\(body)","html_url":"https://github.com/o/r/releases/tag/\(tag)",
     "assets":[{"name":"\(asset)","browser_download_url":"https://\(host)/\(path)/releases/download/\(tag)/\(asset)","size":123}]}
    """.utf8)
}

private func parse(_ d: Data, key: String? = nil) -> AppUpdate? { UpdateChecker.parse(releaseJSON: d, trustedKeyBlob: key ?? signer.blob, repo: "o/r") }

@Test func parsesAReleaseWithDmgAndChecksum() {
    let u = parse(releaseJSON())
    #expect(u?.version == "0.2.0")
    #expect(u?.sha256 == String(repeating: "a", count: 64))
    #expect(u?.dmgURL.absoluteString == "https://github.com/o/r/releases/download/v0.2.0/IPTVMac.dmg")
    #expect(u?.notes.hasPrefix("Notes here.") == true)
}

@Test func refusesReleasesItCannotVerify() throws {
    #expect(parse(releaseJSON(draft: true)) == nil)
    #expect(parse(releaseJSON(pre: true)) == nil)
    #expect(parse(releaseJSON(sha: nil)) == nil)            // never install without a checksum
    #expect(parse(releaseJSON(asset: "other.zip")) == nil)  // no dmg
    #expect(parse(releaseJSON(tag: "latest")) == nil)       // tag is not a version
    #expect(parse(Data("<html>".utf8)) == nil)
    // the signature, not the checksum line, is what makes a release ours:
    #expect(parse(releaseJSON(signed: false)) == nil)                         // checksum only (what a stolen GitHub token could publish)
    #expect(parse(releaseJSON(signWith: try TestSigner())) == nil)            // signed by someone else's key
    #expect(parse(releaseJSON(tag: "v0.2.0", signTag: "v0.1.0")) == nil)      // a valid old signature replayed on another tag
    #expect(parse(releaseJSON(host: "evil.example")) == nil)                  // DMG hosted somewhere else
    #expect(parse(releaseJSON(path: "attacker/repo")) == nil)                 // another repository's asset
}

@Test func releaseSignatureInteroperatesWithSshKeygenAndRejectsTampering() throws {
    let msg = ReleaseSignature.message(tag: "v1.2.3", sha256: String(repeating: "b", count: 64))
    let sig = try signer.sign(msg)
    #expect(ReleaseSignature.verify(signatureBase64: sig, message: msg, trustedBlobBase64: signer.blob))
    #expect(!ReleaseSignature.verify(signatureBase64: sig, message: msg + Data([0]), trustedBlobBase64: signer.blob))
    #expect(!ReleaseSignature.verify(signatureBase64: sig, message: msg, trustedBlobBase64: try TestSigner().blob))
    #expect(!ReleaseSignature.verify(signatureBase64: try signer.sign(msg, namespace: "file"), message: msg, trustedBlobBase64: signer.blob))   // other namespace
    #expect(!ReleaseSignature.verify(signatureBase64: "AAAA", message: msg, trustedBlobBase64: signer.blob))
    #expect(!ReleaseSignature.verify(signatureBase64: sig + "AAAA", message: msg, trustedBlobBase64: signer.blob))
    // the pinned production key is a well-formed ed25519 key
    #expect(ReleaseSignature.rawKey(fromBlob: Data(base64Encoded: ReleaseSignature.publicKeyBlob)!)?.count == 32)
}

// MARK: network (shares MockURLProtocol, so it must live in the serialized SyncTests suite)

extension SyncTests {
    @Test func checkReturnsOnlyNewerVersions() async throws {
        MockURLProtocol.handler = { _ in (200, releaseJSON(tag: "v0.2.0")) }
        let s = mockSession(), k = signer.blob
        #expect(try await UpdateChecker.check(current: "0.1.2", session: s, repo: "o/r", trustedKeyBlob: k)?.version == "0.2.0")
        #expect(try await UpdateChecker.check(current: "0.2.0", session: s, repo: "o/r", trustedKeyBlob: k) == nil)
        #expect(try await UpdateChecker.check(current: "0.3.0", session: s, repo: "o/r", trustedKeyBlob: k) == nil)
        #expect(try await UpdateChecker.check(current: "garbage", session: s, repo: "o/r", trustedKeyBlob: k) == nil)   // unknown current version: do nothing
        MockURLProtocol.handler = { _ in (200, releaseJSON(tag: "v0.2.0", signed: false)) }
        #expect(try await UpdateChecker.check(current: "0.1.2", session: s, repo: "o/r", trustedKeyBlob: k) == nil)      // unsigned: ignored
        MockURLProtocol.handler = { _ in (403, Data("rate limited".utf8)) }
        await #expect(throws: IPTVError.http(403)) { try await UpdateChecker.check(current: "0.1.0", session: s, repo: "o/r", trustedKeyBlob: k) }
    }

    @Test func downloadVerifiesTheChecksum() async throws {
        let payload = Data("pretend dmg".utf8)
        let good = AppUpdate(version: "0.2.0", notes: "", dmgURL: URL(string: "https://h/IPTVMac.dmg")!, sha256: sha256Hex(payload))
        MockURLProtocol.handler = { _ in (200, payload) }
        let file = try await UpdateChecker.downloadDMG(good, session: mockSession())
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(try Data(contentsOf: file) == payload)
        var bad = good; bad.sha256 = String(repeating: "0", count: 64)
        await #expect(throws: UpdateError.checksumMismatch) { try await UpdateChecker.downloadDMG(bad, session: mockSession()) }
        MockURLProtocol.handler = { _ in (404, Data()) }
        await #expect(throws: IPTVError.http(404)) { try await UpdateChecker.downloadDMG(good, session: mockSession()) }
    }
}

// MARK: install (real hdiutil / codesign / sh)

private func makeFakeAppDMG(version: String, in dir: URL) throws -> URL {
    let src = dir.appendingPathComponent("src"); let app = src.appendingPathComponent("IPTVMac.app/Contents")
    try FileManager.default.createDirectory(at: app.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
    try "#!/bin/sh\nexit 0\n".write(to: app.appendingPathComponent("MacOS/IPTVMac"), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: app.appendingPathComponent("MacOS/IPTVMac").path)
    let plist: [String: Any] = ["CFBundleExecutable": "IPTVMac", "CFBundleIdentifier": "test.iptvmac", "CFBundlePackageType": "APPL",
                                "CFBundleShortVersionString": version]
    try (plist as NSDictionary).write(to: app.appendingPathComponent("Info.plist"))
    try run("/usr/bin/codesign", ["--force", "--sign", "-", src.appendingPathComponent("IPTVMac.app").path])
    let dmg = dir.appendingPathComponent("t.dmg")
    try run("/usr/bin/hdiutil", ["create", "-quiet", "-volname", "IPTVMac", "-srcfolder", src.path, "-format", "UDZO", dmg.path])
    return dmg
}

@discardableResult func run(_ tool: String, _ args: [String]) throws -> Int32 {
    let p = Process(); p.executableURL = URL(fileURLWithPath: tool); p.arguments = args
    p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
    try p.run(); p.waitUntilExit()
    if p.terminationStatus != 0 { throw NSError(domain: "run", code: Int(p.terminationStatus)) }
    return p.terminationStatus
}

@Test func stagesTheAppFromADmgAndChecksItsVersion() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-upd-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let dmg = try makeFakeAppDMG(version: "9.9.9", in: dir)
    let staged = try UpdateInstaller.stage(dmg: dmg, expectedVersion: "9.9.9", into: dir.appendingPathComponent("stage"))
    #expect(FileManager.default.fileExists(atPath: staged.appendingPathComponent("Contents/Info.plist").path))
    #expect(staged.lastPathComponent == "IPTVMac.app")
    #expect(throws: UpdateError.self) { try UpdateInstaller.stage(dmg: dmg, expectedVersion: "1.0.0", into: dir.appendingPathComponent("stage2")) }
    // identity: another app, or an older/equal version, must not be staged
    #expect(throws: UpdateError.self) { try UpdateInstaller.stage(dmg: dmg, expectedVersion: "9.9.9", into: dir.appendingPathComponent("s4"), expectedBundleID: "some.other.app") }
    #expect(throws: UpdateError.self) { try UpdateInstaller.stage(dmg: dmg, expectedVersion: "9.9.9", into: dir.appendingPathComponent("s5"), currentVersion: "9.9.9") }
    #expect(throws: UpdateError.self) { try UpdateInstaller.stage(dmg: dmg, expectedVersion: "9.9.9", into: dir.appendingPathComponent("s6"), currentVersion: "10.0.0") }
    _ = try UpdateInstaller.stage(dmg: dmg, expectedVersion: "9.9.9", into: dir.appendingPathComponent("s7"), expectedBundleID: "test.iptvmac", currentVersion: "0.3.5")
    #expect(throws: UpdateError.self) { try UpdateInstaller.stage(dmg: dir.appendingPathComponent("missing.dmg"), expectedVersion: "9.9.9", into: dir.appendingPathComponent("stage3")) }
    // leaves nothing mounted
    let mounted = Process(); let pipe = Pipe(); mounted.executableURL = URL(fileURLWithPath: "/sbin/mount"); mounted.standardOutput = pipe
    try mounted.run(); mounted.waitUntilExit()
    #expect(!String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).contains(dir.path))
}

@Test func swapReplacesTheAppAfterTheProcessExits() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-swap-\(UUID().uuidString)")
    let target = dir.appendingPathComponent("IPTVMac.app"), staged = dir.appendingPathComponent("new/IPTVMac.app")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
    try "old".write(to: target.appendingPathComponent("v.txt"), atomically: true, encoding: .utf8)
    try "new".write(to: staged.appendingPathComponent("v.txt"), atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: dir) }
    let waiter = Process(); waiter.executableURL = URL(fileURLWithPath: "/bin/sleep"); waiter.arguments = ["1"]
    try waiter.run()                                                // "the app": the swap must wait for this pid
    let swapper = try UpdateInstaller.scheduleSwap(pid: waiter.processIdentifier, target: target, staged: staged, relaunch: false)
    try await_(0.3)
    #expect(try String(contentsOf: target.appendingPathComponent("v.txt"), encoding: .utf8) == "old")   // not yet: still running
    waiter.waitUntilExit(); swapper.waitUntilExit()
    #expect(swapper.terminationStatus == 0)
    #expect(try String(contentsOf: target.appendingPathComponent("v.txt"), encoding: .utf8) == "new")
    #expect(!FileManager.default.fileExists(atPath: staged.path))
    #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains(".old") }.isEmpty)   // backup cleaned
}

@Test func swapKeepsTheOldAppWhenTheNewOneIsMissing() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-swap2-\(UUID().uuidString)")
    let target = dir.appendingPathComponent("IPTVMac.app")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try "old".write(to: target.appendingPathComponent("v.txt"), atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: dir) }
    let swapper = try UpdateInstaller.scheduleSwap(pid: 999_999, target: target, staged: dir.appendingPathComponent("nope/IPTVMac.app"), relaunch: false)
    swapper.waitUntilExit()
    #expect(try String(contentsOf: target.appendingPathComponent("v.txt"), encoding: .utf8) == "old")
}

private func await_(_ s: Double) throws { Thread.sleep(forTimeInterval: s) }
