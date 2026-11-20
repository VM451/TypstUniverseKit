// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UniverseExplorerApp",
    platforms: [.macOS(.v26), .iOS(.v26), .visionOS(.v26)],
    dependencies: [.package(path: "../..")],
    targets: [.executableTarget(name: "UniverseExplorerApp", dependencies: [
        .product(name: "TypstUniverseCore", package: "TypstUniverseKit"),
        .product(name: "TypstUniverseStorage", package: "TypstUniverseKit"),
        .product(name: "TypstUniverseUI", package: "TypstUniverseKit")
    ])]
)
