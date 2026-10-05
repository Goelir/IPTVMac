// swift-tools-version: 6.0
import PackageDescription

// Core-only for now; CLibMPV / IPTVPlayer / IPTVMac targets are added in Task 9 once libmpv is installed.
let package = Package(
    name: "IPTVMac",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(name: "IPTVCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "IPTVCoreTests", dependencies: ["IPTVCore"]),
    ],
    swiftLanguageModes: [.v5]
)
