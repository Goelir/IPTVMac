import Testing
import Foundation
@testable import IPTVMac

@Test func durationReadsAsHoursAndMinutes() {
    func h(_ n: Int) -> String { String(format: L("unit.hoursShort"), n) }
    func m(_ n: Int) -> String { String(format: L("unit.minutesShort"), n) }
    #expect(InfoMetaLine.duration(105) == "\(h(1)) \(m(45))")
    #expect(InfoMetaLine.duration(120) == h(2))
    #expect(InfoMetaLine.duration(45) == m(45))
    #expect(InfoMetaLine.duration(59) == m(59))
    #expect(InfoMetaLine.duration(60) == h(1))
}

@Test func everyLanguageTranslatesTheDetailsSheet() throws {
    let keys = ["info.details", "info.plot", "info.cast", "info.director", "info.genre", "info.year", "info.rating", "info.duration",
                "info.country", "info.trailer", "info.play", "info.empty", "info.loading", "info.error", "unit.hoursShort"]
    for lang in InterfaceLanguage.codes {
        let u = try #require(l10nBundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: lang))
        let t = try #require(NSDictionary(contentsOf: u) as? [String: String])
        for k in keys { #expect(t[k]?.isEmpty == false, "\(lang) \(k)") }
        #expect(t["unit.hoursShort"]?.components(separatedBy: "%d").count == 2, "\(lang) hours needs exactly one %d")
    }
}
