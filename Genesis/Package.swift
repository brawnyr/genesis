// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Genesis",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Genesis",
            path: "Genesis"
        ),
        .testTarget(
            name: "GenesisTests",
            dependencies: ["Genesis"],
            path: "Tests"
        )
    ]
)
