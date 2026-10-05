#!/bin/bash
# Wrapper for `swift` on a machine with only Command Line Tools.
# The macOS 27 SDK declares SwiftUI's @State/@Environment/... as macros whose plugin ships only with Xcode,
# so SwiftUI code does not compile against it. The 26.5 SDK (also in the CLT) does not have that problem.
# Usage: scripts/swift.sh build | test | run IPTVMac ...
SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
[ -d "$SDK" ] && export SDKROOT="$SDK"
exec swift "$@"
