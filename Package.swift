// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "TypstUniverseKit",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .visionOS(.v27)
    ],
    products: [
        .library(name: "TypstUniverseCore", targets: ["TypstUniverseCore"]),
        .library(name: "TypstUniverseStorage", targets: ["TypstUniverseStorage"]),
        .library(name: "TypstUniverseUI", targets: ["TypstUniverseUI"]),
        .library(name: "TypstUniverseKit", targets: ["TypstUniverseCore", "TypstUniverseStorage", "TypstUniverseUI"])
    ],
    dependencies: [
        // Build-time only: powers `swift package generate-documentation`.
        // Never linked into library products.
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "TypstUniverseCore",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "TypstUniverseStorage",
            dependencies: ["TypstUniverseCore"]
        ),
        .target(
            name: "TypstUniverseUI",
            dependencies: ["TypstUniverseCore", "TypstUniverseStorage"],
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "TypstUniverseCoreTests",
            dependencies: ["TypstUniverseCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "TypstUniverseStorageTests",
            dependencies: ["TypstUniverseCore", "TypstUniverseStorage"]
        ),
        .testTarget(
            name: "TypstUniverseUITests",
            dependencies: ["TypstUniverseCore", "TypstUniverseStorage", "TypstUniverseUI"]
        )
    ]
)
