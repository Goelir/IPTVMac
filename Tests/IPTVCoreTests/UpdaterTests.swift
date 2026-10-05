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

private func releaseJSON(tag: String = "v0.2.0", draft: Bool = false, pre: Bool = false, sha: String? = String(repeating: "a", count: 64),
                         asset: String = "IPTVMac.dmg") -> Data {
    let body = "Notes here.\\n\\n" + (sha.map { "SHA-256 of IPTVMac.dmg: `\($0)`" } ?? "no checksum")
    return Data("""
    {"tag_name":"\(tag)","draft":\(draft),"prerelease":\(pre),"body":"\(body)","html_url":"https://github.com/o/r/releases/tag/\(tag)",
     "assets":[{"name":"\(asset)","browser_download_url":"https://github.com/o/r/releases/download/\(tag)/\(asset)","size":123}]}
    """.utf8)
}

@Test func parsesAReleaseWithDmgAndChecksum() {
    let u = UpdateChecker.parse(releaseJSON: releaseJSON())
    #expect(u?.version == "0.2.0")
    #expect(u?.sha256 == String(repeating: "a", count: 64))
    #expect(u?.dmgURL.absoluteString == "https://github.com/o/r/releases/download/v0.2.0/IPTVMac.dmg")
    #expect(u?.notes.hasPrefix("Notes here.") == true)
}

@Test func refusesReleasesItCannotVerify() {
    #expect(UpdateChecker.parse(releaseJSON: releaseJSON(draft: true)) == nil)
    #expect(UpdateChecker.parse(releaseJSON: releaseJSON(pre: true)) == nil)
    #expect(UpdateChecker.parse(releaseJSON: releaseJSON(sha: nil)) == nil)            // never install without a checksum
    #expect(UpdateChecker.parse(releaseJSON: releaseJSON(asset: "other.zip")) == nil)  // no dmg
    #expect(UpdateChecker.parse(releaseJSON: releaseJSON(tag: "latest")) == nil)       // tag is not a version
    #expect(UpdateChecker.parse(releaseJSON: Data("<html>".utf8)) == nil)
}

// MARK: network (shares MockURLProtocol, so it must live in the serialized SyncTests suite)

extension SyncTests {
    @Test func checkReturnsOnlyNewerVersions() async throws {
        MockURLProtocol.handler = { _ in (200, releaseJSON(tag: "v0.2.0")) }
        let s = mockSession()
        #expect(try await UpdateChecker.check(current: "0.1.2", session: s)?.version == "0.2.0")
        #expect(try await UpdateChecker.check(current: "0.2.0", session: s) == nil)
        #expect(try await UpdateChecker.check(current: "0.3.0", session: s) == nil)
        #expect(try await UpdateChecker.check(current: "garbage", session: s) == nil)   // unknown current version: do nothing
        MockURLProtocol.handler = { _ in (403, Data("rate limited".utf8)) }
        await #expect(throws: IPTVError.http(403)) { try await UpdateChecker.check(current: "0.1.0", session: s) }
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

@discardableResult private func run(_ tool: String, _ args: [String]) throws -> Int32 {
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
