// swift-tools-version:6.0
import Foundation
import PackageDescription

// Resolve the vendored static library against the manifest location rather
// than the process working directory: `swift build` must work from anywhere,
// and a relative `-L` silently produced an unlinkable package elsewhere.
let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let needleLibraryPath = packageDirectory.appendingPathComponent("vendor/macos-arm64").path

let swiftUIFlags: [SwiftSetting] = [
    .unsafeFlags(["-Xfrontend", "-disable-round-trip-debug-types"])
]

let package = Package(
    name: "Saylo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "saylo-cli", targets: ["SayloCLI"]),
        .executable(name: "Saylo", targets: ["SayloApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CNeedle",
            path: "Sources/CNeedle",
            linkerSettings: [
                .unsafeFlags(["-L\(needleLibraryPath)"]),
                .linkedLibrary("needle"),
                .linkedLibrary("c++"),
                .linkedFramework("Accelerate"),
            ]
        ),
        .target(
            name: "SayloCore",
            dependencies: ["CNeedle"],
            path: "Sources/SayloCore"
        ),
        .target(
            name: "DesignSystem",
            path: "Sources/SayloApp/Design",
            swiftSettings: swiftUIFlags
        ),
        .executableTarget(
            name: "SayloApp",
            dependencies: ["SayloCore", "DesignSystem"],
            path: "Sources/SayloApp",
            exclude: ["Design"],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: swiftUIFlags + [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-swift-version", "5"])
            ]
        ),
        .executableTarget(
            name: "SayloCLI",
            dependencies: ["SayloCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-swift-version", "5"])
            ]
        ),
        .testTarget(name: "SayloCoreTests", dependencies: ["SayloCore"]),
    ]
)
