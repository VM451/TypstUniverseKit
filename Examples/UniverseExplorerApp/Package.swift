// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "UniverseExplorerApp",
    platforms: [.macOS(.v27), .iOS(.v27), .visionOS(.v27)],
    dependencies: [.package(path: "../..")],
    targets: [.executableTarget(name: "UniverseExplorerApp", dependencies: [
        .product(name: "TypstUniverseCore", package: "TypstUniverseKit"),
        .product(name: "TypstUniverseStorage", package: "TypstUniverseKit"),
        .product(name: "TypstUniverseUI", package: "TypstUniverseKit")
    ])]
)
