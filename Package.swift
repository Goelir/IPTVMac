// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IPTVMac",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .systemLibrary(name: "CLibMPV", pkgConfig: "mpv", providers: [.brew(["mpv"])]),
        .target(name: "IPTVPlayer", dependencies: ["CLibMPV"]),
        .target(name: "IPTVCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .executableTarget(
            name: "IPTVMac",
            dependencies: ["IPTVCore", "IPTVPlayer"],
            resources: [.process("Resources")]
        ),
        // ponytail: Command Line Tools only: the swift-testing macro plugin is not found on rebuilds without this flag.
        .testTarget(name: "IPTVCoreTests", dependencies: ["IPTVCore"],
                    swiftSettings: [.unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])]),
        .testTarget(name: "IPTVPlayerTests", dependencies: ["IPTVPlayer"],
                    swiftSettings: [.unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])]),
        .testTarget(name: "IPTVMacTests", dependencies: ["IPTVMac"],
                    swiftSettings: [.unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])]),
    ],
    swiftLanguageModes: [.v5]
)
