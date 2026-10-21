// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bark",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7"),
    ],
    targets: [
        .executableTarget(
            name: "Bark",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            path: "Sources/Bark",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
