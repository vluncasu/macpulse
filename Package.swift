// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPulseCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MacPulseCore", targets: ["MacPulseCore"])
    ],
    targets: [
        .target(
            name: "MacPulseCore",
            path: "CoreSources"
        ),
        .testTarget(
            name: "MacPulseCoreTests",
            dependencies: ["MacPulseCore"],
            path: "CoreTests"
        )
    ]
)
