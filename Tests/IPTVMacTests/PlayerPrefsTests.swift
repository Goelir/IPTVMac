import AppKit
import Testing
import Foundation
@testable import IPTVMac

private func request(_ name: String) -> PlayRequest {
    PlayRequest(title: name, url: URL(fileURLWithPath: "/nonexistent/\(name).mkv"), isLive: false, item: nil)
}

@MainActor @Test func sleepTimerFiresOnceAtTheDeadlineAndSurvivesTheNextItem() {
    let pm = PlayerModel(request: request("a"))
    defer { pm.close() }
    var fired = 0
    pm.onSleep = { fired += 1 }
    let t0 = Date()
    pm.setSleep(minutes: 15, now: t0)
    #expect(pm.sleepMinutesLeft == 15)
    pm.tick(now: t0 + 600)
    #expect(pm.sleepMinutesLeft == 5 && fired == 0)
    pm.replace(with: request("b"))             // next channel / episode in the same player
    pm.tick(now: t0 + 840)
    #expect(pm.sleepMinutesLeft == 1 && fired == 0, "the timer must carry over to the next item")
    pm.tick(now: t0 + 901)
    #expect(fired == 1 && pm.sleepMinutesLeft == nil)
    pm.tick(now: t0 + 1000)
    #expect(fired == 1, "it fires once")
}

@MainActor @Test func sleepTimerOffAndClosedPlayerNeverFire() {
    let pm = PlayerModel(request: request("a"))
    var fired = 0
    pm.onSleep = { fired += 1 }
    let t0 = Date()
    pm.setSleep(minutes: 15, now: t0)
    pm.setSleep(minutes: 0, now: t0)
    #expect(pm.sleepMinutesLeft == nil)
    pm.tick(now: t0 + 5000)
    #expect(fired == 0)
    pm.setSleep(minutes: 15, now: t0)
    pm.close()
    pm.tick(now: t0 + 5000)
    #expect(fired == 0, "a closed player is not ticked")
}

/// The saved preferences reach the engine when the player is created, and a stored value that no longer exists falls back.
@MainActor @Test func playerModelAppliesTheStoredScaleAndBuffer() {
    let d = UserDefaults.standard
    defer { d.removeObject(forKey: "videoScale"); d.removeObject(forKey: "bufferSize") }
    d.set("stretch", forKey: "videoScale"); d.set("large", forKey: "bufferSize")
    let pm = PlayerModel(request: request("a"))
    defer { pm.close() }
    #expect(pm.mpv.flag("keepaspect") == false && pm.mpv.double("panscan") == 0)
    #expect(pm.mpv.double("demuxer-max-bytes") == Double(256 << 20) && pm.mpv.double("demuxer-readahead-secs") == 60)
    d.set("fill", forKey: "videoScale"); d.set("small", forKey: "bufferSize")
    pm.applyVideoScale(); pm.applyBuffer()
    #expect(pm.mpv.flag("keepaspect") && pm.mpv.double("panscan") == 1)
    #expect(pm.mpv.double("demuxer-max-bytes") == Double(16 << 20))
    d.set("bogus", forKey: "videoScale"); d.set("bogus", forKey: "bufferSize")
    pm.applyVideoScale(); pm.applyBuffer()
    #expect(pm.mpv.flag("keepaspect") && pm.mpv.double("panscan") == 0)
    #expect(pm.mpv.double("demuxer-max-bytes") == Double(64 << 20) && pm.mpv.double("demuxer-readahead-secs") == 20)
}

/// The skip buttons use the numbered system image of the chosen step; a missing symbol would draw an empty button.
@Test func everySkipStepAndTheSleepIconHaveASystemImage() {
    for n in PlayerSettings.seekSteps {
        for name in ["gobackward.\(n)", "goforward.\(n)"] {
            #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
        }
    }
    for name in ["moon.zzz", "moon.zzz.fill"] { #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)") }
}

/// A missing translation shows the raw key, and a different number of %d / %@ crashes String(format:).
@Test func allLanguagesHaveTheSameKeysAndFormatSpecifiers() throws {
    func table(_ lang: String) throws -> [String: String] {
        let u = try #require(l10nBundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: lang))
        return try #require(NSDictionary(contentsOf: u) as? [String: String])
    }
    func specs(_ s: String) -> [String] { s.split(separator: "%", omittingEmptySubsequences: false).dropFirst().map { String($0.prefix(1)) } }
    let en = try table("en")
    for lang in ["he", "ar"] {
        let t = try table(lang)
        #expect(Set(t.keys) == Set(en.keys), "\(lang): missing \(Set(en.keys).subtracting(t.keys)), extra \(Set(t.keys).subtracting(en.keys))")
        for (k, v) in en { #expect(specs(t[k] ?? "") == specs(v), "\(lang) \(k)") }
    }
    for k in ["settings.seekStep", "unit.seconds", "unit.minutes", "unit.minutesShort", "player.skipBack", "player.sleep", "settings.bufferHint"] {
        #expect(en[k]?.isEmpty == false, "\(k)")
    }
}
