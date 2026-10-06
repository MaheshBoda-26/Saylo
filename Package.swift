// swift-tools-version:6.0
import PackageDescription

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
                .unsafeFlags(["-Lvendor/macos-arm64"]),
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
            path: "Sources/SayloApp/Design"
        ),
        .executableTarget(
            name: "SayloApp",
            dependencies: ["SayloCore", "DesignSystem"],
            path: "Sources/SayloApp",
            exclude: ["Design"],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
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