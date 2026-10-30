// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "scheman",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "scheman"),
        .testTarget(name: "schemanTests", dependencies: ["scheman"]),
    ]
)
