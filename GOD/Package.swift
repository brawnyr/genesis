// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GOD",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GOD",
            path: "GOD",
            exclude: ["GOD.entitlements"]
        ),
        .testTarget(
            name: "GODTests",
            dependencies: ["GOD"],
            path: "Tests"
        )
    ]
)
