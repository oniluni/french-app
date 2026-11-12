// swift-tools-version: 5.10
import PackageDescription

// Pure logic of the app. Foundation only, so it also builds and tests on Linux.
let package = Package(
    name: "FrenchCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "FrenchCore", targets: ["FrenchCore"])],
    targets: [
        .target(name: "FrenchCore"),
        .testTarget(name: "FrenchCoreTests", dependencies: ["FrenchCore"]),
    ]
)
