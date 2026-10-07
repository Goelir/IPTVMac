import Testing
@testable import IPTVPlayer

@Test func presetsAreSortedAndInsideTheRange() {
    let p = PlaybackSpeed.presets
    #expect(p == p.sorted())
    #expect(p.first == PlaybackSpeed.range.lowerBound && p.last == PlaybackSpeed.range.upperBound)
    #expect(p.contains(1) && p.contains(2))
    #expect(p.allSatisfy { PlaybackSpeed.normalized($0) == $0 }, "every preset must survive the rounding unchanged")
}

@Test(arguments: [(0.0, 0.25), (-3.0, 0.25), (0.1, 0.25), (9.0, 4.0), (4.01, 4.0), (1.0, 1.0),
                  (1.12, 1.1), (1.13, 1.15), (0.52, 0.5), (1.999, 2.0), (.nan, 1.0), (.infinity, 1.0)])
func normalizedClampsAndRoundsToFiveHundredths(_ input: Double, _ expected: Double) {
    #expect(PlaybackSpeed.normalized(input) == expected)
}

@Test(arguments: [(1.0, 1.25), (1.25, 1.5), (2.0, 2.5), (3.0, 4.0), (4.0, 4.0), (0.25, 0.5), (1.15, 1.25), (0.1, 0.5)])
func stepUpGoesToTheNextPreset(_ from: Double, _ to: Double) {
    #expect(PlaybackSpeed.step(from: from, up: true) == to)
}

@Test(arguments: [(1.0, 0.75), (0.5, 0.25), (0.25, 0.25), (4.0, 3.0), (1.15, 1.0), (1.3, 1.25), (9.0, 3.0)])
func stepDownGoesToThePreviousPreset(_ from: Double, _ to: Double) {
    #expect(PlaybackSpeed.step(from: from, up: false) == to)
}

@Test func stepsWalkThroughAllPresetsAndStopAtTheEnds() {
    var s = PlaybackSpeed.range.lowerBound
    var seen = [s]
    for _ in 0..<30 { s = PlaybackSpeed.step(from: s, up: true); if seen.last != s { seen.append(s) } }
    #expect(seen == PlaybackSpeed.presets)
    for _ in 0..<30 { s = PlaybackSpeed.step(from: s, up: false) }
    #expect(s == PlaybackSpeed.range.lowerBound)
}

@Test func labelsUseADotAndDropTrailingZeros() {
    #expect(PlaybackSpeed.label(1) == "1×")
    #expect(PlaybackSpeed.label(1.5) == "1.5×")
    #expect(PlaybackSpeed.label(0.25) == "0.25×")
    #expect(PlaybackSpeed.label(2.0) == "2×")
    #expect(PlaybackSpeed.label(PlaybackSpeed.normalized(1.05)) == "1.05×")
}
