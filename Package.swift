// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Perekluk",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "PereklukCore",
            path: "Sources/PereklukCore",
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),
        .executableTarget(
            name: "Perekluk",
            dependencies: ["PereklukCore"],
            path: "Sources/Perekluk",
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(
            name: "PereklukTests",
            dependencies: ["PereklukCore"],
            path: "Tests/PereklukTests"
        ),
    ]
)
