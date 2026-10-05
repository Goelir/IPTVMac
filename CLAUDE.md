# IPTVMac

At the start of every session and after every task or notable action: read `PROJECT_STATUS.md`, update it (task board, log, next action, blockers), commit it with the work, then continue from "Next action".

Spec: `docs/superpowers/specs/2026-10-05-iptvmac-design.md`. Plan: `docs/superpowers/plans/2026-10-05-iptvmac.md`.

Build and test with `scripts/swift.sh build|test|run` (not bare `swift`): Command Line Tools only, the wrapper selects the macOS 26.5 SDK so SwiftUI compiles.
