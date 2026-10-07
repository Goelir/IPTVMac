import Testing
@testable import IPTVCore

// `next` mutates, which #expect cannot do inside its expression.
private func toggles(_ f: inout FullscreenSync, isFull: Bool, ready: Bool = true) -> Bool { f.next(isFull: isFull, ready: ready) }

@Test func fullscreenRequestIssuedMidTransitionWaitsAndIsJudgedAgainstTheStateThen() {
    var f = FullscreenSync()
    f.want(true)
    #expect(toggles(&f, isFull: false))                        // play: enter full screen, transition running
    f.want(false)                                              // stop within the animation: AppKit would drop a toggle now
    #expect(!toggles(&f, isFull: false))                       // (styleMask says "not full" until the transition ends: must not be trusted)
    f.transitionEnded(isFull: true)
    #expect(toggles(&f, isFull: true))                         // now leave what we entered
    f.transitionEnded(isFull: false)
    #expect(!toggles(&f, isFull: false))                       // nothing left to do
}

@Test func fullscreenWaitsWhileTheWindowCannotTakeIt() {
    var f = FullscreenSync()
    f.want(true)
    #expect(!toggles(&f, isFull: false, ready: false))         // sheet closing, window minimized or app hidden
    #expect(toggles(&f, isFull: false))                        // the request was kept
}

@Test func onlyTheFullscreenWeEnteredIsLeft() {
    var f = FullscreenSync()
    f.want(false)
    #expect(!toggles(&f, isFull: true))                        // the user entered it: stop must not leave it
    f.want(true)
    #expect(!toggles(&f, isFull: true))                        // already there

    var g = FullscreenSync()
    g.want(true)
    #expect(toggles(&g, isFull: false))
    g.transitionEnded(isFull: true)
    g.transitionEnded(isFull: false)                           // the user left it by hand: forget that we entered it
    g.want(false)
    #expect(!toggles(&g, isFull: true))                        // a later full screen of the user's own stays
}

@Test func fullscreenIsForgottenWhenTheWindowCloses() {
    var f = FullscreenSync()
    f.want(true)
    #expect(toggles(&f, isFull: false))
    f.reset()
    #expect(!f.busy)
    f.want(false)
    #expect(!toggles(&f, isFull: true))
}
