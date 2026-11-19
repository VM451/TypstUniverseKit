// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UniverseExplorerApp",
    platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v1)],
    dependencies: [.package(path: "../..")],
    targets: [.executableTarget(name: "UniverseExplorerApp", dependencies: [
        .product(name: "TypstUniverseCore", package: "TypstUniverseKit"),
        .product(name: "TypstUniverseStorage", package: "TypstUniverseKit"),
        .product(name: "TypstUniverseUI", package: "TypstUniverseKit")
    ])]
)
