import Testing
import Foundation
@testable import IPTVMac

@Test func pointerPositionMapsToTimeAcrossTheBar() {
    #expect(SeekBarMath.time(x: 0, width: 400, duration: 200) == 0)
    #expect(SeekBarMath.time(x: 100, width: 400, duration: 200) == 50)
    #expect(SeekBarMath.time(x: 400, width: 400, duration: 200) == 200)
    #expect(SeekBarMath.fraction(x: 300, width: 400) == 0.75)
}

@Test func pointerOutsideTheBarIsClampedToItsEnds() {
    #expect(SeekBarMath.time(x: -30, width: 400, duration: 200) == 0)
    #expect(SeekBarMath.time(x: 999, width: 400, duration: 200) == 200)
    #expect(SeekBarMath.fraction(x: .infinity, width: 400) == 0)
}

@Test func degenerateBarsAndDurationsGiveZeroNotNaN() {
    #expect(SeekBarMath.time(x: 10, width: 0, duration: 200) == 0)
    #expect(SeekBarMath.time(x: 10, width: -5, duration: 200) == 0)
    #expect(SeekBarMath.time(x: 10, width: 400, duration: 0) == 0)
    #expect(SeekBarMath.time(x: 10, width: 400, duration: -3) == 0)
    #expect(SeekBarMath.time(x: .nan, width: 400, duration: 200) == 0)
    #expect(SeekBarMath.time(x: 10, width: 400, duration: .nan) == 0)
    #expect(SeekBarMath.fraction(of: 5, in: 0) == 0 && SeekBarMath.fraction(of: .nan, in: 10) == 0)
    #expect(SeekBarMath.fraction(of: 50, in: 10) == 1 && SeekBarMath.fraction(of: -5, in: 10) == 0)
}

@Test func bubbleCentresOnTheMarkerAndStaysInsideThePlayer() {
    // player 1000 wide, bubble 188 wide, 8 pt margin
    #expect(SeekBarMath.bubbleLeft(center: 500, width: 188, container: 1000, margin: 8) == 406)
    #expect(SeekBarMath.bubbleLeft(center: 20, width: 188, container: 1000, margin: 8) == 8, "stuck to the left edge")
    #expect(SeekBarMath.bubbleLeft(center: 990, width: 188, container: 1000, margin: 8) == 804, "stuck to the right edge")
    #expect(SeekBarMath.bubbleLeft(center: -50, width: 188, container: 1000, margin: 8) == 8)
    #expect(SeekBarMath.bubbleLeft(center: 5000, width: 188, container: 1000, margin: 8) == 804)
}

@Test func bubbleWiderThanThePlayerSticksToTheLeftMargin() {
    #expect(SeekBarMath.bubbleLeft(center: 100, width: 188, container: 150, margin: 8) == 8)
    #expect(SeekBarMath.bubbleLeft(center: 100, width: 188, container: 0, margin: 8) == 8)
}

@Test func pointerFollowsTheMarkerInsideTheBubbleAndKeepsClearOfTheCorners() {
    #expect(SeekBarMath.pointerX(center: 500, left: 406, width: 188, inset: 16) == 94, "centred when the bubble is centred")
    #expect(SeekBarMath.pointerX(center: 20, left: 8, width: 188, inset: 16) == 16, "marker near the left edge: pointer stops before the rounded corner")
    #expect(SeekBarMath.pointerX(center: 990, left: 804, width: 188, inset: 16) == 172)
}

@Test(arguments: [(0.0, "0:00"), (5.9, "0:05"), (65, "1:05"), (600, "10:00"), (3599.9, "59:59"), (3600, "1:00:00"), (3725, "1:02:05"),
                  (36000, "10:00:00"), (-4, "0:00"), (.nan, "0:00"), (.infinity, "0:00")])
func timeLabelUsesMinutesAndOnlyShowsHoursWhenNeeded(_ s: Double, _ text: String) {
    #expect(SeekBarMath.format(s) == text)
}
