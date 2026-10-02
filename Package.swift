// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadioRai",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RadioRai", targets: ["RadioRai"])
    ],
    targets: [
        .executableTarget(name: "RadioRai", path: "Sources/RadioRai")
    ]
)
